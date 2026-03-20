# ==============================================================================
# UNIT TESTS - QUESTION CLASSIFICATION (04_classify_questions.R)
# ==============================================================================

# --- Helper: create mock options list ---
mock_options <- function(texts) {
  lapply(seq_along(texts), function(i) {
    list(code = as.character(10000 + i), text = texts[i], key = paste0("q-1-o-", 10000 + i))
  })
}

mock_question <- function(q_text = "Test question", n_cols = 1, structure = "simple") {
  cols <- lapply(seq_len(n_cols), function(i) {
    list(col_index = i, q_num = "1", q_id = "1", structure = structure,
         question_text = q_text, row_label = paste0("opt", i), col_label = NA)
  })
  list(question_text = q_text, columns = cols, structure = structure)
}

empty_hints <- list(
  question_text = NA_character_,
  brackets = NA_character_,
  type = NA_character_,
  has_rank_keyword = FALSE
)

# --- detect_nps ---

test_that("detect_nps identifies 0-10 scale as NPS", {
  opts <- mock_options(as.character(0:10))
  result <- detect_nps(opts, 11L, "how likely are you to recommend")
  expect_equal(result, "NPS")
})

test_that("detect_nps identifies 0-10 scale without keyword as NPS", {
  opts <- mock_options(as.character(0:10))
  result <- detect_nps(opts, 11L, "some other question")
  expect_equal(result, "NPS")
})

test_that("detect_nps returns NULL for non-0-10 scales", {
  opts <- mock_options(as.character(1:11))
  result <- detect_nps(opts, 11L, "recommend")
  expect_null(result)
})

test_that("detect_nps returns NULL for wrong option count", {
  opts <- mock_options(as.character(1:5))
  result <- detect_nps(opts, 5L, "recommend")
  expect_null(result)
})

# --- detect_likert ---

test_that("detect_likert identifies agree/disagree scales", {
  opts <- mock_options(c("Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"))
  result <- detect_likert(opts, 5L)
  expect_equal(result, "Likert")
})

test_that("detect_likert returns NULL for non-Likert options", {
  opts <- mock_options(c("Yes", "No", "Maybe"))
  result <- detect_likert(opts, 3L)
  expect_null(result)
})

test_that("detect_likert returns NULL for empty options", {
  result <- detect_likert(list(), 0L)
  expect_null(result)
})

# --- detect_rating_by_keywords ---

test_that("detect_rating_by_keywords identifies satisfaction scales", {
  opts <- mock_options(c("Very Dissatisfied", "Dissatisfied", "Neutral",
                         "Satisfied", "Very Satisfied"))
  result <- detect_rating_by_keywords(opts, 5L)
  expect_equal(result, "Rating")
})

test_that("detect_rating_by_keywords returns NULL for non-rating counts", {
  opts <- mock_options(c("Satisfied", "Dissatisfied", "Neutral"))
  result <- detect_rating_by_keywords(opts, 3L)
  expect_null(result)
})

# --- detect_type_from_word_hints ---

test_that("detect_type_from_word_hints maps slider to Numeric", {
  hints <- list(type = "slider")
  expect_equal(detect_type_from_word_hints(hints), "Numeric")
})

test_that("detect_type_from_word_hints maps numeric to Numeric", {
  hints <- list(type = "numeric")
  expect_equal(detect_type_from_word_hints(hints), "Numeric")
})

test_that("detect_type_from_word_hints maps textbox to Open_End", {
  hints <- list(type = "textbox")
  expect_equal(detect_type_from_word_hints(hints), "Open_End")
})

test_that("detect_type_from_word_hints returns NULL for NA type", {
  hints <- list(type = NA)
  expect_null(detect_type_from_word_hints(hints))
})

test_that("detect_type_from_word_hints returns NULL for unknown type", {
  hints <- list(type = "dropdown")
  expect_null(detect_type_from_word_hints(hints))
})

# --- detect_ranking ---

test_that("detect_ranking returns Ranking when hint has rank keyword and multi-col", {
  hints <- list(has_rank_keyword = TRUE, brackets = NA)
  result <- detect_ranking(hints, "please rank these items", 5)
  expect_equal(result, "Ranking")
})

test_that("detect_ranking returns NULL for single column", {
  hints <- list(has_rank_keyword = TRUE, brackets = NA)
  result <- detect_ranking(hints, "rank these", 1)
  expect_null(result)
})

test_that("detect_ranking detects from question text patterns", {
  hints <- list(has_rank_keyword = FALSE, brackets = NA)

  expect_equal(detect_ranking(hints, "this is a ranking question", 3), "Ranking")
  expect_equal(detect_ranking(hints, "rank from most to least important", 3), "Ranking")
  expect_equal(detect_ranking(hints, "prioritise these options", 3), "Ranking")
  expect_equal(detect_ranking(hints, "prioritize these options", 3), "Ranking")
})

test_that("detect_ranking returns NULL when no ranking signal", {
  hints <- list(has_rank_keyword = FALSE, brackets = NA)
  result <- detect_ranking(hints, "which do you prefer?", 3)
  expect_null(result)
})

# --- detect_multi_mention ---

test_that("detect_multi_mention returns Multi_Mention for [] brackets", {
  hints <- list(brackets = "[]", type = NA)
  q <- mock_question(n_cols = 1)
  result <- detect_multi_mention(hints, q, 1)
  expect_equal(result, "Multi_Mention")
})

test_that("detect_multi_mention detects from grid_or_multi structure", {
  hints <- list(brackets = NA, type = NA)
  q <- mock_question(n_cols = 3, structure = "grid_or_multi")
  result <- detect_multi_mention(hints, q, 3)
  expect_equal(result, "Multi_Mention")
})

test_that("detect_multi_mention returns NULL for () brackets", {
  hints <- list(brackets = "()", type = NA)
  q <- mock_question(n_cols = 1)
  result <- detect_multi_mention(hints, q, 1)
  expect_null(result)
})

# --- detect_numeric_rating ---

test_that("detect_numeric_rating identifies mostly-numeric options as Rating", {
  opts <- mock_options(c("0", "1", "2", "3", "4", "5", "Don't know"))
  result <- detect_numeric_rating(opts, 7L)
  expect_equal(result, "Rating")
})

test_that("detect_numeric_rating returns NULL when too few numeric options", {
  opts <- mock_options(c("1", "Yes", "No", "Maybe", "Sometimes"))
  result <- detect_numeric_rating(opts, 5L)
  expect_null(result)
})

test_that("detect_numeric_rating returns NULL for empty options", {
  result <- detect_numeric_rating(list(), 0L)
  expect_null(result)
})

# --- classify_variable_type (integration) ---

test_that("classify_variable_type returns NPS for 0-10 recommend question", {
  q <- mock_question("How likely are you to recommend?")
  opts <- mock_options(as.character(0:10))
  result <- classify_variable_type(q, opts, empty_hints)
  expect_equal(result, "NPS")
})

test_that("classify_variable_type returns Likert for agree/disagree", {
  q <- mock_question("How much do you agree?")
  opts <- mock_options(c("Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"))
  result <- classify_variable_type(q, opts, empty_hints)
  expect_equal(result, "Likert")
})

test_that("classify_variable_type returns Single_Response for non-scale options", {
  q <- mock_question("What is your gender?")
  opts <- mock_options(c("Male", "Female", "Other"))
  result <- classify_variable_type(q, opts, empty_hints)
  expect_equal(result, "Single_Response")
})

test_that("classify_variable_type returns Open_End for no options", {
  q <- mock_question("Please describe your experience")
  result <- classify_variable_type(q, list(), empty_hints)
  expect_equal(result, "Open_End")
})

test_that("classify_variable_type returns Numeric for slider hint", {
  q <- mock_question("Rate on a scale")
  hints <- list(type = "slider", brackets = NA, has_rank_keyword = FALSE,
                question_text = NA)
  result <- classify_variable_type(q, list(), hints)
  expect_equal(result, "Numeric")
})

# --- Classification hierarchy precedence ---

test_that("NPS takes precedence over Likert when 0-10 scale has agree keyword", {
  # Edge case: 11 options including "agree" but also 0-10
  opts <- mock_options(as.character(0:10))
  q <- mock_question("How likely to recommend?")
  result <- classify_variable_type(q, opts, empty_hints)
  expect_equal(result, "NPS")
})
