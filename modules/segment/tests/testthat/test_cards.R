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


test_that("the Segment Action Cards section renders in the HTML report", {
  # Guards the page-builder gate + builder shape. The section previously keyed
  # on a non-existent "segment_cards" field, and once pointed at enhanced$cards
  # iterated the wrapper list and hit the atomic cards_text vector ("$ operator
  # is invalid for atomic vectors"). It must now render the inner per-card list.
  skip_if_not(requireNamespace("htmltools", quietly = TRUE), "htmltools not installed")
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  td <- generate_segment_test_data(n = 300, k_true = 3, n_vars = 10, seed = 42)
  cfg <- generate_test_config(td, mode = "final", method = "kmeans", k_fixed = 3)
  cfg$generate_action_cards <- TRUE
  cfg$scale_max <- 10

  num <- td$data[, td$clustering_vars, drop = FALSE]
  for (col in td$clustering_vars) {
    num[[col]][is.na(num[[col]])] <- median(num[[col]], na.rm = TRUE)
  }
  sc <- scale(num)
  dl <- list(original_data = td$data, data = td$data, scaled_data = sc,
             clustering_data = num, clustering_vars = td$clustering_vars, config = cfg,
             scale_params = list(center = attr(sc, "scaled:center"),
                                 scale = attr(sc, "scaled:scale")))
  g <- segment_guard_init()
  cr <- run_clustering(dl, cfg, g)
  vm <- calculate_validation_metrics(data = sc, model = cr$model, k = cr$k,
                                     clusters = cr$clusters, calculate_gap = FALSE)
  sn <- paste("Segment", seq_len(cr$k))
  pr <- create_full_segment_profile(data = td$data, clusters = cr$clusters,
          clustering_vars = td$clustering_vars, profile_vars = cfg$profile_vars)
  cards <- generate_segment_cards(td$data, cr$clusters, td$clustering_vars,
             sn, td$question_labels, 10)

  results <- list(mode = "final", cluster_result = cr, validation_metrics = vm,
    profile_result = pr, segment_names = sn, enhanced = list(cards = cards),
    data_list = dl)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  rep <- generate_segment_html_report(results = results, config = cfg, output_path = out)

  expect_equal(rep$status, "PASS")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl('data-seg-section="cards"', html, fixed = TRUE),
              info = "Cards section must be present in the rendered report")
  expect_true(grepl("seg-action-card-name", html, fixed = TRUE),
              info = "Individual cards must render")
  expect_true(grepl("Recommended Actions", html, fixed = TRUE),
              info = "Card content (recommended actions) must render")
})
