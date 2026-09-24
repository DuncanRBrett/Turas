# ==============================================================================
# TEST SUITE: Tracking Crosstab Engine (Phase 2)
# ==============================================================================
# Tests for build_tracking_crosstab() and helper functions.
# ==============================================================================

library(testthat)

context("Tracking Crosstab Engine")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source dependencies
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracking_crosstab_engine.R"))

# ==============================================================================
# HELPERS: Create synthetic trend results
# ==============================================================================

create_mock_config <- function() {
  list(
    waves = data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Jan 2024", "Apr 2024", "Jul 2024"),
      DataFile = c("w1.csv", "w2.csv", "w3.csv"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31")),
      stringsAsFactors = FALSE
    ),
    settings = list(
      project_name = "Test Tracking",
      baseline_wave = "W1",
      default_rating_specs = "mean"
    ),
    banner = data.frame(
      BreakVariable = c("Total"),
      BreakLabel = c("Overall"),
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(
      QuestionCode = c("Q_SAT", "Q_NPS"),
      MetricLabel = c("Satisfaction", "NPS Score"),
      TrackingSpecs = c("mean,top2_box", "nps_score,promoters_pct"),
      Section = c("Brand Health", "Brand Health"),
      SortOrder = c(1, 2),
      stringsAsFactors = FALSE
    ),
    config_path = "/mock/config.xlsx"
  )
}

create_mock_question_map <- function() {
  list(
    standard_to_wave = list(
      Q_SAT = list(W1 = "Q10", W2 = "Q11", W3 = "Q12"),
      Q_NPS = list(W1 = "Q15", W2 = "Q15", W3 = "Q15")
    ),
    question_metadata = data.frame(
      QuestionCode = c("Q_SAT", "Q_NPS"),
      QuestionText = c("How satisfied are you?", "Likelihood to recommend?"),
      QuestionType = c("Rating", "NPS"),
      stringsAsFactors = FALSE
    )
  )
}

# Create a rating_enhanced trend result
create_mock_rating_trend <- function() {
  list(
    question_code = "Q_SAT",
    question_text = "How satisfied are you?",
    question_type = "Rating",
    metric_type = "rating_enhanced",
    tracking_specs = c("mean", "top2_box"),
    wave_results = list(
      W1 = list(
        available = TRUE,
        metrics = list(mean = 8.2, sd = 1.5, top2_box = 0.52),
        n_unweighted = 500,
        n_weighted = 500,
        values = rnorm(500, 8.2, 1.5),
        weights = rep(1, 500)
      ),
      W2 = list(
        available = TRUE,
        metrics = list(mean = 8.5, sd = 1.4, top2_box = 0.55),
        n_unweighted = 480,
        n_weighted = 480,
        values = rnorm(480, 8.5, 1.4),
        weights = rep(1, 480)
      ),
      W3 = list(
        available = TRUE,
        metrics = list(mean = 8.7, sd = 1.3, top2_box = 0.58),
        n_unweighted = 510,
        n_weighted = 510,
        values = rnorm(510, 8.7, 1.3),
        weights = rep(1, 510)
      )
    ),
    changes = list(
      mean = list(
        W1_to_W2 = list(from_wave = "W1", to_wave = "W2", absolute_change = 0.3, direction = "up"),
        W2_to_W3 = list(from_wave = "W2", to_wave = "W3", absolute_change = 0.2, direction = "up")
      ),
      top2_box = list(
        W1_to_W2 = list(from_wave = "W1", to_wave = "W2", absolute_change = 0.03, direction = "up"),
        W2_to_W3 = list(from_wave = "W2", to_wave = "W3", absolute_change = 0.03, direction = "up")
      )
    ),
    significance = list(
      mean = list(
        W1_vs_W2 = list(significant = TRUE, p_value = 0.01, direction = "up"),
        W2_vs_W3 = list(significant = FALSE, p_value = 0.15, direction = "up")
      ),
      top2_box = list(
        W1_vs_W2 = list(significant = TRUE, p_value = 0.03, direction = "up"),
        W2_vs_W3 = list(significant = FALSE, p_value = 0.20, direction = "up")
      )
    )
  )
}

# Create an NPS trend result
create_mock_nps_trend <- function() {
  list(
    question_code = "Q_NPS",
    question_text = "Likelihood to recommend?",
    question_type = "NPS",
    metric_type = "nps",
    wave_results = list(
      W1 = list(nps = 32, promoters_pct = 45, passives_pct = 42, detractors_pct = 13,
                n_unweighted = 500, n_weighted = 500, eff_n = 500, available = TRUE),
      W2 = list(nps = 38, promoters_pct = 48, passives_pct = 42, detractors_pct = 10,
                n_unweighted = 480, n_weighted = 480, eff_n = 480, available = TRUE),
      W3 = list(nps = 41, promoters_pct = 50, passives_pct = 41, detractors_pct = 9,
                n_unweighted = 510, n_weighted = 510, eff_n = 510, available = TRUE)
    ),
    changes = list(
      W1_to_W2 = list(from_wave = "W1", to_wave = "W2", absolute_change = 6, direction = "up"),
      W2_to_W3 = list(from_wave = "W2", to_wave = "W3", absolute_change = 3, direction = "up")
    ),
    significance = list(
      W1_vs_W2 = list(significant = TRUE, p_value = 0.02, direction = "up"),
      W2_vs_W3 = list(significant = FALSE, p_value = 0.25, direction = "up")
    )
  )
}


# ==============================================================================
# TESTS: build_tracking_crosstab() - overall structure
# ==============================================================================

test_that("build_tracking_crosstab produces correct top-level structure", {
  config <- create_mock_config()
  question_map <- create_mock_question_map()
  trend_results <- list(
    Q_SAT = create_mock_rating_trend(),
    Q_NPS = create_mock_nps_trend()
  )

  result <- build_tracking_crosstab(trend_results, config, question_map)

  expect_true(is.list(result))
  expect_true("metrics" %in% names(result))
  expect_true("waves" %in% names(result))
  expect_true("wave_labels" %in% names(result))
  expect_true("banner_segments" %in% names(result))
  expect_true("baseline_wave" %in% names(result))
  expect_true("sections" %in% names(result))
  expect_true("metadata" %in% names(result))

  expect_equal(result$waves, c("W1", "W2", "W3"))
  expect_equal(result$baseline_wave, "W1")
  expect_equal(result$banner_segments, "Total")
})

test_that("build_tracking_crosstab produces correct number of metric rows", {
  config <- create_mock_config()
  question_map <- create_mock_question_map()
  trend_results <- list(
    Q_SAT = create_mock_rating_trend(),
    Q_NPS = create_mock_nps_trend()
  )

  result <- build_tracking_crosstab(trend_results, config, question_map)

  # Q_SAT with "mean,top2_box" = 2 rows
  # Q_NPS with "nps_score,promoters_pct" = 2 rows
  # Total = 4 metric rows
  expect_equal(length(result$metrics), 4)
})


# ==============================================================================
# TESTS: Metric row structure
# ==============================================================================

test_that("metric_row has correct fields", {
  config <- create_mock_config()
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  # Only track Q_SAT
  config$tracked_questions <- config$tracked_questions[1, ]

  result <- build_tracking_crosstab(trend_results, config, question_map)
  row <- result$metrics[[1]]

  expect_true("question_code" %in% names(row))
  expect_true("metric_label" %in% names(row))
  expect_true("metric_name" %in% names(row))
  expect_true("section" %in% names(row))
  expect_true("sort_order" %in% names(row))
  expect_true("segments" %in% names(row))

  expect_equal(row$question_code, "Q_SAT")
  expect_equal(row$section, "Brand Health")
})


# ==============================================================================
# TESTS: extract_metric_value
# ==============================================================================

test_that("extract_metric_value handles rating_enhanced correctly", {
  wr <- list(available = TRUE, metrics = list(mean = 8.5, top2_box = 0.55))

  expect_equal(extract_metric_value(wr, "rating_enhanced", "mean"), 8.5)
  expect_equal(extract_metric_value(wr, "rating_enhanced", "top2_box"), 0.55)
  expect_true(is.na(extract_metric_value(wr, "rating_enhanced", "nonexistent")))
})

test_that("extract_metric_value handles NPS correctly", {
  wr <- list(nps = 38, promoters_pct = 48, detractors_pct = 10,
             n_unweighted = 480, available = TRUE)

  expect_equal(extract_metric_value(wr, "nps", "nps"), 38)
  expect_equal(extract_metric_value(wr, "nps", "nps_score"), 38)  # nps_field_map maps "nps_score" → "nps"
  expect_equal(extract_metric_value(wr, "nps", "promoters_pct"), 48)
})

test_that("extract_metric_value handles unavailable wave", {
  wr <- list(available = FALSE, metrics = list())
  # Won't reach extraction since extract_segment_metric checks available first
  # But if called directly:
  expect_true(is.na(extract_metric_value(wr, "rating_enhanced", "mean")))
})

test_that("extract_metric_value handles proportions metric_type", {
  # calculate_single_choice_trend_enhanced returns metric_type = "proportions"
  # with proportions as a named numeric vector
  wr <- list(
    available = TRUE,
    proportions = c("Yes" = 45.2, "No" = 54.8),
    n_unweighted = 100
  )

  # Category spec: "category:Yes" → metric_name = "category_yes"
  expect_equal(extract_metric_value(wr, "proportions", "category_yes"), 45.2)
  expect_equal(extract_metric_value(wr, "proportions", "category_no"), 54.8)

  # Missing category returns NA
  expect_true(is.na(extract_metric_value(wr, "proportions", "category_maybe")))
})

test_that("extract_metric_value handles category names with spaces (normalized matching)", {
  # Codes like "Brand A" get normalized to "brand_a" by normalize_metric_name
  wr <- list(
    available = TRUE,
    proportions = c("Brand A" = 32.1, "Brand B" = 67.9),
    n_unweighted = 100
  )

  expect_equal(extract_metric_value(wr, "proportions", "category_brand_a"), 32.1)
  expect_equal(extract_metric_value(wr, "proportions", "category_brand_b"), 67.9)
})


# ==============================================================================
# TESTS: Segment values extraction
# ==============================================================================

test_that("segment values are extracted correctly for rating", {
  config <- create_mock_config()
  config$tracked_questions <- config$tracked_questions[1, ]  # Q_SAT only
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)

  # First metric row should be Q_SAT mean
  mean_row <- result$metrics[[1]]
  expect_equal(mean_row$metric_name, "mean")

  total_seg <- mean_row$segments$Total
  expect_equal(total_seg$values$W1, 8.2)
  expect_equal(total_seg$values$W2, 8.5)
  expect_equal(total_seg$values$W3, 8.7)
})


# ==============================================================================
# TESTS: Change calculations
# ==============================================================================

test_that("vs previous changes are calculated correctly", {
  config <- create_mock_config()
  config$tracked_questions <- config$tracked_questions[1, ]
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)
  mean_row <- result$metrics[[1]]
  total_seg <- mean_row$segments$Total

  # W2 - W1 = 8.5 - 8.2 = 0.3
  expect_equal(total_seg$change_vs_previous$W2, 0.3, tolerance = 0.001)
  # W3 - W2 = 8.7 - 8.5 = 0.2
  expect_equal(total_seg$change_vs_previous$W3, 0.2, tolerance = 0.001)
})

test_that("vs baseline changes are calculated correctly", {
  config <- create_mock_config()
  config$tracked_questions <- config$tracked_questions[1, ]
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)
  mean_row <- result$metrics[[1]]
  total_seg <- mean_row$segments$Total

  # vs baseline (W1): W2-W1 = 0.3, W3-W1 = 0.5
  expect_equal(total_seg$change_vs_baseline$W2, 0.3, tolerance = 0.001)
  expect_equal(total_seg$change_vs_baseline$W3, 0.5, tolerance = 0.001)
})

test_that("baseline wave W2 changes calculations correctly", {
  config <- create_mock_config()
  config$settings$baseline_wave <- "W2"
  config$tracked_questions <- config$tracked_questions[1, ]
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)
  mean_row <- result$metrics[[1]]
  total_seg <- mean_row$segments$Total

  # vs baseline (W2): W1-W2 = 8.2-8.5 = -0.3, W3-W2 = 8.7-8.5 = 0.2
  expect_equal(total_seg$change_vs_baseline$W1, -0.3, tolerance = 0.001)
  expect_equal(total_seg$change_vs_baseline$W3, 0.2, tolerance = 0.001)
})


# ==============================================================================
# TESTS: Significance extraction
# ==============================================================================

test_that("significance is extracted for consecutive waves", {
  config <- create_mock_config()
  config$tracked_questions <- config$tracked_questions[1, ]
  question_map <- create_mock_question_map()
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)
  mean_row <- result$metrics[[1]]
  total_seg <- mean_row$segments$Total

  # W1 vs W2: significant (TRUE in mock)
  expect_true(total_seg$sig_vs_previous$W2)
  # W2 vs W3: not significant (FALSE in mock)
  expect_false(total_seg$sig_vs_previous$W3)
})


# ==============================================================================
# TESTS: Labelling
# ==============================================================================

test_that("generate_metric_label uses override when single spec", {
  label <- generate_metric_label(
    spec = "mean",
    metric_label_override = "Satisfaction",
    question_text = "How satisfied?",
    metric_type = "rating_enhanced",
    specs_list = c("mean")
  )
  expect_equal(label, "Satisfaction")
})

test_that("generate_metric_label adds suffix when multiple specs", {
  label <- generate_metric_label(
    spec = "mean",
    metric_label_override = "Satisfaction",
    question_text = "How satisfied?",
    metric_type = "rating_enhanced",
    specs_list = c("mean", "top2_box")
  )
  expect_equal(label, "Satisfaction (Mean)")
})

test_that("generate_metric_label handles NPS specs", {
  label <- generate_metric_label(
    spec = "nps_score",
    metric_label_override = NA,
    question_text = "Likelihood to recommend?",
    metric_type = "nps",
    specs_list = c("nps_score", "promoters_pct")
  )
  expect_equal(label, "Likelihood to recommend? (NPS)")
})

test_that("generate_metric_label handles category spec", {
  label <- generate_metric_label(
    spec = "category:Yes",
    metric_label_override = "Awareness",
    question_text = "Are you aware?",
    metric_type = "single_choice",
    specs_list = c("category:Yes")
  )
  expect_equal(label, "Awareness")
})


# ==============================================================================
# TESTS: Sorting
# ==============================================================================

test_that("metric rows are sorted by section then sort_order", {
  config <- create_mock_config()
  question_map <- create_mock_question_map()
  trend_results <- list(
    Q_SAT = create_mock_rating_trend(),
    Q_NPS = create_mock_nps_trend()
  )

  result <- build_tracking_crosstab(trend_results, config, question_map)

  # All in "Brand Health" section, Q_SAT (sort 1) before Q_NPS (sort 2)
  sections <- vapply(result$metrics, function(r) r$section, character(1))
  expect_true(all(sections == "Brand Health"))

  orders <- vapply(result$metrics, function(r) r$sort_order, numeric(1))
  expect_true(all(diff(orders) >= 0))  # Non-decreasing
})


# ==============================================================================
# TESTS: Edge cases
# ==============================================================================

test_that("handles missing trend results for a question", {
  config <- create_mock_config()
  question_map <- create_mock_question_map()
  # Q_NPS has no trend results
  trend_results <- list(Q_SAT = create_mock_rating_trend())

  result <- build_tracking_crosstab(trend_results, config, question_map)

  # Only Q_SAT metrics should be present
  q_codes <- vapply(result$metrics, function(r) r$question_code, character(1))
  expect_true(all(q_codes == "Q_SAT"))
})

test_that("handles empty tracked questions", {
  config <- create_mock_config()
  config$tracked_questions <- config$tracked_questions[0, ]  # Empty
  question_map <- create_mock_question_map()
  trend_results <- list()

  result <- build_tracking_crosstab(trend_results, config, question_map)
  expect_equal(length(result$metrics), 0)
})


# ==============================================================================
# TESTS: the report states the alpha and minimum base the tests used
# ==============================================================================
# Significance arrows are tested at the `alpha` setting and gated on
# `minimum_base` (trend_significance.R). The Excel "Confidence Level" row and
# the HTML footer printed the separate `confidence_level` setting and a fixed
# base of 30, so a study run at alpha 0.10 was labelled 95%.

test_that("crosstab metadata states 1 - alpha, not a separate confidence_level", {
  config <- create_mock_config()
  config$settings$alpha <- 0.10
  config$settings$confidence_level <- 0.95   # stale label, not what was tested
  config$settings$minimum_base <- 50
  capture.output(result <- build_tracking_crosstab(
    list(Q_SAT = create_mock_rating_trend(), Q_NPS = create_mock_nps_trend()),
    config, create_mock_question_map()))
  expect_equal(result$metadata$alpha, 0.10)
  expect_equal(result$metadata$confidence_level, 0.90)
  expect_equal(result$metadata$minimum_base, 50)
})

test_that("crosstab metadata defaults to alpha 0.05 and base 30", {
  config <- create_mock_config()
  capture.output(result <- build_tracking_crosstab(
    list(Q_SAT = create_mock_rating_trend()), config, create_mock_question_map()))
  expect_equal(result$metadata$confidence_level, 0.95)
  expect_equal(result$metadata$minimum_base, 30)
})

test_that("a confidence_level that disagrees with alpha is reported as unused", {
  config <- create_mock_config()
  config$settings$alpha <- 0.10
  config$settings$confidence_level <- 0.95
  out <- capture.output(build_tracking_crosstab(
    list(Q_SAT = create_mock_rating_trend()), config, create_mock_question_map()))
  expect_true(any(grepl("confidence_level = 0.95 is not used", out, fixed = TRUE)))
})


# ==============================================================================
# TESTS: multi-mention rows carry values (robustness review 24 Sep 2026)
# ==============================================================================
# "auto" was not expanded to the option columns and values were looked up at
# the top level, so the crosstab and the HTML report built from it showed a
# multi-mention question as rows named "auto" and "% Any" with every cell
# blank. Shape below is calculate_multi_mention_trend()'s.

mm_trend <- function() {
  wr <- function(a, b, any) list(available = TRUE, n_unweighted = 90, eff_n = 70,
                                 mention_proportions = list(Q30_1 = a, Q30_2 = b),
                                 additional_metrics = list(any_mention_pct = any),
                                 tracked_columns = c("Q30_1", "Q30_2"))
  list(question_code = "CHAN", question_text = "Channels", question_type = "Multi_Mention",
       metric_type = "multi_mention", tracking_specs = "auto,any",
       tracked_columns = c("Q30_1", "Q30_2"),
       wave_results = list(W1 = wr(40, 20, 50), W2 = wr(55, 22, 66), W3 = wr(60, 25, 70)),
       changes = list(),
       significance = list(
         Q30_1 = list(W1_vs_W2 = list(significant = TRUE), W2_vs_W3 = list(significant = FALSE)),
         Q30_2 = list(W1_vs_W2 = list(significant = FALSE), W2_vs_W3 = list(significant = FALSE)),
         any_mention_pct = list(W1_vs_W2 = list(significant = TRUE), W2_vs_W3 = list(significant = FALSE))))
}

test_that("crosstab expands multi-mention auto into options and fills any-mention", {
  config <- create_mock_config()
  config$tracked_questions <- data.frame(QuestionCode = "CHAN", MetricLabel = "Channels",
                                         TrackingSpecs = "auto,any", Section = "S", SortOrder = 1,
                                         stringsAsFactors = FALSE)
  qm <- create_mock_question_map()
  qm$standard_to_wave$CHAN <- list(W1 = "Q30", W2 = "Q30", W3 = "Q30")
  qm$question_metadata <- rbind(qm$question_metadata, data.frame(
    QuestionCode = "CHAN", QuestionText = "Channels used", QuestionType = "Multi_Mention",
    stringsAsFactors = FALSE))
  capture.output(res <- build_tracking_crosstab(list(CHAN = mm_trend()), config, qm))
  rows <- res$metrics[vapply(res$metrics, function(m) m$question_code == "CHAN", logical(1))]
  by_name <- setNames(rows, vapply(rows, function(m) m$metric_name, character(1)))
  expect_setequal(names(by_name), c("q30_1", "q30_2", "any"))
  vals <- function(nm) unlist(by_name[[nm]]$segments$Total$values)
  expect_equal(unname(vals("q30_1")), c(40, 55, 60))
  expect_equal(unname(vals("q30_2")), c(20, 22, 25))
  expect_equal(unname(vals("any")), c(50, 66, 70))
  sig <- by_name[["q30_1"]]$segments$Total$sig_vs_previous
  expect_true(isTRUE(sig$W2))
  expect_true(isTRUE(by_name[["any"]]$segments$Total$sig_vs_previous$W2))
})
