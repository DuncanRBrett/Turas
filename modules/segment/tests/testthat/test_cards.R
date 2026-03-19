# ==============================================================================
# SEGMENT MODULE TESTS - ACTION CARDS
# ==============================================================================

test_that("generate_segment_cards produces correct card count", {
  set.seed(42)
  data <- data.frame(
    q1 = c(rnorm(50, 8, 1), rnorm(50, 3, 1), rnorm(50, 5, 1)),
    q2 = c(rnorm(50, 7, 1), rnorm(50, 4, 1), rnorm(50, 6, 1)),
    q3 = c(rnorm(50, 9, 1), rnorm(50, 2, 1), rnorm(50, 5, 1)),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 50), rep(2, 50), rep(3, 50))
  segment_names <- c("Champions", "At-Risk", "Moderate")

  result <- generate_segment_cards(
    data = data,
    clusters = clusters,
    clustering_vars = c("q1", "q2", "q3"),
    segment_names = segment_names,
    scale_max = 10
  )

  expect_true(is.list(result))
  expect_equal(length(result$cards), 3)
  expect_equal(nrow(result$cards_df), 3)
  expect_equal(result$cards_df$Segment_Name, segment_names)
})

test_that("generate_segment_cards includes defining traits", {
  set.seed(42)
  data <- data.frame(
    q1 = c(rnorm(50, 9, 0.5), rnorm(50, 2, 0.5)),
    q2 = c(rnorm(50, 5, 0.5), rnorm(50, 5, 0.5)),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 50), rep(2, 50))

  result <- generate_segment_cards(
    data = data,
    clusters = clusters,
    clustering_vars = c("q1", "q2"),
    scale_max = 10
  )

  # Each card should have defining traits
  for (card in result$cards) {
    expect_true(length(card$defining_traits) > 0)
  }
})

test_that("generate_segment_cards with question labels", {
  set.seed(42)
  data <- data.frame(
    q1 = c(rnorm(50, 8, 1), rnorm(50, 3, 1)),
    q2 = c(rnorm(50, 6, 1), rnorm(50, 7, 1)),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 50), rep(2, 50))

  labels <- c(q1 = "Product Quality", q2 = "Service Speed")

  result <- generate_segment_cards(
    data = data,
    clusters = clusters,
    clustering_vars = c("q1", "q2"),
    question_labels = labels,
    scale_max = 10
  )

  expect_true(is.list(result))
  expect_equal(length(result$cards), 2)
})

test_that("format_card_text produces formatted output", {
  card <- list(
    segment_name = "Test Segment",
    size = "100 respondents (50%)",
    headline = "High-satisfaction group",
    defining_traits = c("Strong q1", "Weak q2"),
    strengths = c("High quality"),
    pain_points = c("No major issues"),
    recommended_actions = c("Monitor", "Engage")
  )

  text <- format_card_text(card)
  expect_true(is.character(text))
  expect_true(grepl("Test Segment", text))
  expect_true(grepl("High-satisfaction", text))
})

test_that("cards_df has required columns", {
  set.seed(42)
  data <- data.frame(
    q1 = rnorm(60),
    q2 = rnorm(60),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 30), rep(2, 30))

  result <- generate_segment_cards(
    data = data,
    clusters = clusters,
    clustering_vars = c("q1", "q2"),
    scale_max = 10
  )

  expected_cols <- c("Segment", "Segment_Name", "Size_N", "Size_Pct",
                     "Headline", "Key_Traits", "Strengths", "Pain_Points", "Actions")
  expect_true(all(expected_cols %in% names(result$cards_df)))
})
