# ==============================================================================
# TEST SUITE: Trend Dashboard and Significance Matrix on REAL calculator output
# ==============================================================================
# The Dashboard tests in test_dashboard_statistics.R build wave results by
# hand with `mean` and `sd` at the top level. The rating and composite
# calculators store them under `metrics`, and multi-mention results carry
# `mention_proportions`. On a real run the Dashboard read NULL for every
# rating, and the run crashed. These tests feed the writers what the
# calculators actually produce, read the cells back, and check each arrow
# against the trend path's own test of the same pair (consistency gate).
# ==============================================================================

library(testthat)

context("Dashboard and Sig Matrix on real calculator output")

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)
weights_path <- file.path(turas_root, "modules", "shared", "lib", "weights_utils.R")
if (file.exists(weights_path)) source(weights_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "wave_loader.R"))
source(file.path(tracker_root, "lib", "aggregate_wave_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "trend_changes.R"))
source(file.path(tracker_root, "lib", "trend_significance.R"))
source(file.path(tracker_root, "lib", "trend_calculator.R"))
source(file.path(tracker_root, "lib", "tracker_dashboard_reports.R"))


# ------------------------------------------------------------------------------
# Real results from the calculators
# ------------------------------------------------------------------------------

real_results <- function() {
  set.seed(314)
  n <- 150
  mk <- function(shift) {
    data.frame(
      Q10 = sample(1:5, n, replace = TRUE, prob = c(1, 2, 3, 3 + shift, 2 + shift)),
      Q15 = sample(0:10, n, replace = TRUE, prob = c(rep(1, 7), 2, 3, 3 + shift, 3 + shift)),
      Q20 = sample(c("Yes", "No"), n, replace = TRUE, prob = c(0.4 + shift / 10, 0.6 - shift / 10)),
      Q30_1 = ifelse(seq_len(n) > 120, NA, rbinom(n, 1, 0.4 + shift / 10)),
      Q30_2 = ifelse(seq_len(n) > 120, NA, rbinom(n, 1, 0.3)),
      weight_var = rep(c(0.5, 1, 1.5), length.out = n)
    )
  }
  frames <- list(W1 = mk(0), W2 = mk(1), W3 = mk(3))
  mapping <- data.frame(
    QuestionCode = c("SAT", "REC", "AWARE", "CHAN"),
    QuestionText = c("Satisfaction", "Recommend", "Aware", "Channels"),
    QuestionType = c("Rating", "NPS", "Single_Response", "Multi_Mention"),
    TrackingSpecs = c("mean,top2_box", NA, "category:Yes", "auto"),
    W1 = c("Q10", "Q15", "Q20", "Q30"), W2 = c("Q10", "Q15", "Q20", "Q30"),
    W3 = c("Q10", "Q15", "Q20", "Q30"), stringsAsFactors = FALSE)
  config <- list(waves = data.frame(WaveID = c("W1", "W2", "W3"), stringsAsFactors = FALSE),
                 settings = list(alpha = 0.05, minimum_base = 30, decimal_places_ratings = 2,
                                 project_name = "Real results"))
  capture.output(qm <- build_question_map_index(mapping, config))
  st <- data.frame(QuestionCode = "Q10", OptionText = as.character(1:5), DisplayText = as.character(1:5),
                   Index_Weight = 1:5, BoxCategory = NA_character_, ExcludeFromIndex = NA_character_,
                   stringsAsFactors = FALSE)
  structs <- list(W1 = st, W2 = st, W3 = st)
  capture.output({
    res <- list(
      SAT = calculate_rating_trend_enhanced("SAT", qm, frames, config, structs),
      REC = calculate_nps_trend("REC", qm, frames, config, structs),
      AWARE = calculate_single_choice_trend_enhanced("AWARE", qm, frames, config, structs),
      CHAN = calculate_multi_mention_trend("CHAN", qm, frames, config, structs)
    )
  })
  list(results = res, config = config)
}

dashboard_sheet <- function(trend_results, config) {
  wb <- openxlsx::createWorkbook()
  suppressMessages(write_trend_dashboard(wb, trend_results, config))
  df <- openxlsx::read.xlsx(wb, sheet = "Trend_Dashboard", colNames = FALSE, skipEmptyRows = FALSE)
  hdr <- which(df[[1]] == "Code")[1]
  body <- df[(hdr + 1):nrow(df), ]
  names(body) <- make.unique(as.character(unlist(df[hdr, ])))
  body[!is.na(body$Code) & body$Code %in% names(trend_results), ]
}

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

test_that("Dashboard writes a row for every real question type without crashing", {
  rr <- real_results()
  body <- dashboard_sheet(rr$results, rr$config)
  expect_setequal(body$Code, c("SAT", "REC", "AWARE", "CHAN"))
})

test_that("Dashboard latest values are the calculators' headline figures", {
  rr <- real_results()
  body <- dashboard_sheet(rr$results, rr$config)
  # Written as display text: means to decimal_places_ratings (2), shares as
  # "NN.NN%", NPS as a whole number.
  latest <- setNames(as.numeric(sub("%$", "", body$Latest)), body$Code)
  w3 <- function(q) rr$results[[q]]$wave_results$W3
  expect_equal(latest[["SAT"]], round(w3("SAT")$metrics$mean, 2))
  expect_equal(latest[["REC"]], round(w3("REC")$nps, 0))
  expect_equal(latest[["AWARE"]], round(w3("AWARE")$proportions[["Yes"]], 2))
  expect_equal(latest[["CHAN"]], round(w3("CHAN")$mention_proportions$Q30_1, 2))
  expect_match(body$Latest[body$Code == "AWARE"], "%$")
})

test_that("Dashboard vs-previous arrow agrees with the trend path's test of W2 -> W3", {
  rr <- real_results()
  body <- dashboard_sheet(rr$results, rr$config)
  sig_prev <- setNames(body$Sig, body$Code)
  trend_sig <- list(
    SAT = rr$results$SAT$significance$mean$W2_vs_W3,
    REC = rr$results$REC$significance$W2_vs_W3,
    AWARE = rr$results$AWARE$significance$Yes$W2_vs_W3,
    CHAN = rr$results$CHAN$significance$Q30_1$W2_vs_W3
  )
  for (q in names(trend_sig)) {
    s <- trend_sig[[q]]
    expected <- if (isTRUE(s$significant)) c("↑", "↓") else "→"
    expect_true(sig_prev[[q]] %in% expected, info = q)
  }
  # At least one pair in this fixture is significant, so the check has teeth
  expect_true(any(vapply(trend_sig, function(s) isTRUE(s$significant), logical(1))))
})

test_that("Dashboard pairwise p-value equals the trend path's p-value, pair by pair", {
  rr <- real_results()
  r <- rr$results
  view <- function(q, w) dashboard_primary_view(r[[q]], r[[q]]$wave_results[[w]])
  pairs <- list(
    SAT = r$SAT$significance$mean$W2_vs_W3$p_value,
    REC = r$REC$significance$W2_vs_W3$p_value,
    AWARE = r$AWARE$significance$Yes$W2_vs_W3$p_value,
    CHAN = r$CHAN$significance$Q30_1$W2_vs_W3$p_value
  )
  for (q in names(pairs)) {
    a <- view(q, "W2"); b <- view(q, "W3")
    dash <- calculate_pairwise_significance(a$result, b$result, a$metric_type)
    expect_equal(dash$p_value, pairs[[q]], tolerance = 1e-12, info = q)
  }
})

test_that("with banners the Dashboard and Sig Matrix use the Total segment", {
  rr <- real_results()
  nested <- lapply(rr$results, function(x) list(Total = x, Region_North = x))
  body <- dashboard_sheet(nested, rr$config)
  expect_setequal(body$Code, c("SAT", "REC", "AWARE", "CHAN"))

  wb <- openxlsx::createWorkbook()
  suppressMessages(write_all_significance_matrices(wb, nested, rr$config))
  expect_true(all(paste0(c("SAT", "REC", "AWARE", "CHAN"), "_SigMatrix") %in% names(wb)))
})
