# ==============================================================================
# TESTS: ROUTING & SKIP LOGIC DETECTION
# ==============================================================================

test_that("detect_routing_from_text detects 'If Q2 = Yes' pattern", {
  result <- detect_routing_from_text("If Q2 = Yes, show this question")
  expect_true(result$detected)
  expect_true("2" %in% result$references)
  expect_false(is.na(result$condition_text))
})

test_that("detect_routing_from_text detects 'ASK IF Q5' pattern", {
  result <- detect_routing_from_text("ASK IF Q5 = 1 or 2")
  expect_true(result$detected)
  expect_true("5" %in% result$references)
})

test_that("detect_routing_from_text detects 'Based on Q3' pattern", {
  result <- detect_routing_from_text("Based on answer to Q3:")
  expect_true(result$detected)
  expect_true("3" %in% result$references)
})

test_that("detect_routing_from_text detects 'SKIP TO Q10' pattern", {
  result <- detect_routing_from_text("If no, SKIP TO Q10")
  expect_true(result$detected)
  expect_true("10" %in% result$references)
})

test_that("detect_routing_from_text detects '[ROUTING: Q5 = 1,2]' pattern", {
  result <- detect_routing_from_text("[ROUTING: Q5 = 1,2]")
  expect_true(result$detected)
  expect_true("5" %in% result$references)
})

test_that("detect_routing_from_text detects 'Those who selected' pattern", {
  result <- detect_routing_from_text("Those who selected option A in Q7")
  expect_true(result$detected)
  expect_true("7" %in% result$references)
})

test_that("detect_routing_from_text detects 'SHOW IF' pattern", {
  result <- detect_routing_from_text("SHOW IF Q1 = 'Agree'")
  expect_true(result$detected)
  expect_true("1" %in% result$references)
})

test_that("detect_routing_from_text detects 'If response to Q2' pattern", {
  result <- detect_routing_from_text("If response to Q2 is Positive")
  expect_true(result$detected)
  expect_true("2" %in% result$references)
})

test_that("detect_routing_from_text detects 'screener' keyword", {
  result <- detect_routing_from_text("SCREENER: Do you use this product?")
  expect_true(result$detected)
})

test_that("detect_routing_from_text detects 'Only ask if' pattern", {
  result <- detect_routing_from_text("Only ask if respondent is over 18")
  expect_true(result$detected)
})

test_that("detect_routing_from_text returns FALSE for plain text", {
  result <- detect_routing_from_text("How satisfied are you with the product?")
  expect_false(result$detected)
  expect_equal(length(result$references), 0)
  expect_true(is.na(result$condition_text))
})

test_that("detect_routing_from_text handles NULL and NA inputs", {
  expect_false(detect_routing_from_text(NULL)$detected)
  expect_false(detect_routing_from_text(NA)$detected)
  expect_false(detect_routing_from_text("")$detected)
  expect_false(detect_routing_from_text("   ")$detected)
})

test_that("detect_routing_from_text extracts multiple Q references", {
  result <- detect_routing_from_text("If Q2 = Yes and Q3 = No, skip to Q10")
  expect_true(result$detected)
  refs <- result$references
  expect_true("2" %in% refs)
  expect_true("3" %in% refs)
  expect_true("10" %in% refs)
})

# --- Integration: detect_routing on full question structures ---

test_that("detect_routing annotates questions with routing metadata", {
  # Create minimal question structure
  questions <- list(
    "1" = list(
      q_num = "1",
      q_code = "Q01",
      question_text = "How old are you?",
      is_grid = FALSE,
      routing = NULL
    ),
    "2" = list(
      q_num = "2",
      q_code = "Q02",
      question_text = "If Q1 = 18+, what brand do you prefer?",
      is_grid = FALSE,
      routing = NULL
    )
  )

  # Create Word hints with routing
  word_hints <- list(
    "1" = list(
      full_text = "1) How old are you?",
      has_routing_hint = FALSE
    ),
    "2" = list(
      full_text = "2) ASK IF Q1 = 18+: What brand do you prefer?",
      has_routing_hint = TRUE
    )
  )

  result <- detect_routing(questions, word_hints, verbose = FALSE)

  # Q1 should NOT have routing
  expect_false(result[["1"]]$routing$has_routing)

  # Q2 should have routing detected
  expect_true(result[["2"]]$routing$has_routing)
  expect_true("1" %in% result[["2"]]$routing$conditional_on)
})

test_that("detect_routing handles empty questions and hints", {
  questions <- list()
  word_hints <- list()
  result <- detect_routing(questions, word_hints, verbose = FALSE)
  expect_equal(length(result), 0)
})

# --- build_routing_summary ---

test_that("build_routing_summary creates correct data frame", {
  questions <- list(
    "1" = list(
      q_num = "1",
      q_code = "Q01",
      routing = list(
        has_routing = FALSE,
        conditional_on = character(0),
        condition_text = NA_character_,
        confidence = NA_character_,
        source = NA_character_
      )
    ),
    "2" = list(
      q_num = "2",
      q_code = "Q02",
      routing = list(
        has_routing = TRUE,
        conditional_on = c("1"),
        condition_text = "ask if q1",
        confidence = "INFERRED",
        source = "word_text_pattern"
      )
    )
  )

  summary <- build_routing_summary(questions)
  expect_equal(nrow(summary), 1)
  expect_equal(summary$QuestionCode[1], "Q02")
  expect_equal(summary$ConditionalOn[1], "Q1")
  expect_equal(summary$Confidence[1], "INFERRED")
})

test_that("build_routing_summary returns empty df when no routing", {
  questions <- list(
    "1" = list(
      q_num = "1",
      q_code = "Q01",
      routing = list(has_routing = FALSE)
    )
  )

  summary <- build_routing_summary(questions)
  expect_equal(nrow(summary), 0)
  expect_true("QuestionCode" %in% names(summary))
})
