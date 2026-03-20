# ==============================================================================
# UNIT TESTS - TRANSLATION PARSING (02_parse_translation.R)
# ==============================================================================

# --- extract_question_id ---

test_that("extract_question_id extracts ID from question key", {
  expect_equal(extract_question_id("q-2"), "2")
  expect_equal(extract_question_id("q-15"), "15")
  expect_equal(extract_question_id("q-100"), "100")
})

test_that("extract_question_id extracts ID from option key", {
  expect_equal(extract_question_id("q-2-o-10001"), "2")
  expect_equal(extract_question_id("q-15-o-50003"), "15")
})

test_that("extract_question_id returns NA for invalid keys", {
  expect_true(is.na(extract_question_id("invalid")))
  expect_true(is.na(extract_question_id("")))
})

# --- extract_option_code ---

test_that("extract_option_code extracts option code", {
  expect_equal(extract_option_code("q-2-o-10001"), "10001")
  expect_equal(extract_option_code("q-15-o-50003"), "50003")
})

test_that("extract_option_code returns NA for non-option keys", {
  expect_true(is.na(extract_option_code("q-2")))
  expect_true(is.na(extract_option_code("invalid")))
})

# --- get_options_for_question ---

test_that("get_options_for_question returns options when found", {
  td <- list(
    options = list(
      "5" = list(
        list(code = "10001", text = "Yes", key = "q-5-o-10001"),
        list(code = "10002", text = "No", key = "q-5-o-10002")
      )
    )
  )
  result <- get_options_for_question("5", td)
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$text, "Yes")
})

test_that("get_options_for_question returns empty list when not found", {
  td <- list(options = list())
  result <- get_options_for_question("999", td)
  expect_equal(length(result), 0)
})

# --- get_question_text ---

test_that("get_question_text returns text when found", {
  td <- list(questions = list("5" = "What is your age?"))
  result <- get_question_text("5", td)
  expect_equal(result, "What is your age?")
})

test_that("get_question_text returns NA when not found", {
  td <- list(questions = list())
  result <- get_question_text("999", td)
  expect_true(is.na(result))
})
