# M5 - the 2026-06 audit's SUSPECTED silent drops in exploration and combined
# modes, traced at last.
#
# Final mode was hardened after that audit. These two modes never were, and
# tracing them turned up more than the review described: the k-selection
# metrics table was dropping the silhouette column over a NAME MISMATCH, in
# the one report whose whole job is to help an analyst choose k.

.explore_metrics_df <- function() {
  # The column names the ENGINE writes (04_validation.R, the metrics_list
  # data.frame). recommend_k() reads avg_silhouette_width from this frame, so
  # it is the canonical name, not a variant.
  data.frame(
    k = 2:5,
    tot.withinss = c(2400, 1900, 1650, 1500),
    betweenss = c(1100, 1600, 1850, 2000),
    totss = rep(3500, 4),
    betweenss_totss = c(0.31, 0.46, 0.53, 0.57),
    avg_silhouette_width = c(0.41, 0.51, 0.44, 0.39),
    min_segment_pct = c(44, 22, 15, 11)
  )
}

test_that("the k-selection table shows the silhouette it recommends on (M5)", {
  skip_if_not(exists("build_seg_exploration_metrics_table", mode = "function"),
              "exploration report layer not loaded")

  html <- as.character(build_seg_exploration_metrics_table(
    list(metrics_df = .explore_metrics_df())))

  expect_true(grepl("Silhouette", html, fixed = TRUE))
  # The recommendation is max silhouette, so the winning value must be on the
  # page the analyst checks it against.
  expect_true(grepl("0.51", html, fixed = TRUE))
})

test_that("a dropped report section says so on the console (M5)", {
  skip_if_not(exists("build_seg_exploration_metrics_table", mode = "function"),
              "exploration report layer not loaded")

  out <- capture.output(res <- build_seg_exploration_metrics_table(list(metrics_df = NULL)))

  expect_null(res)
  expect_true(any(grepl("skipped", out, ignore.case = TRUE)))
  expect_true(any(grepl("metric", paste(out, collapse = " "), ignore.case = TRUE)))
})

test_that("a dropped k-comparison section says so on the console (M5)", {
  skip_if_not(exists("build_seg_k_comparison_table", mode = "function"),
              "exploration report layer not loaded")

  out <- capture.output(res <- build_seg_k_comparison_table(list(k_summaries = NULL)))

  expect_null(res)
  expect_true(any(grepl("skipped", out, ignore.case = TRUE)))
})

test_that("a dropped recommendation section says so on the console (M5)", {
  skip_if_not(exists("build_seg_recommendation_section", mode = "function"),
              "exploration report layer not loaded")

  out1 <- capture.output(r1 <- build_seg_recommendation_section(list(recommendation = NULL), "#CC9900"))
  out2 <- capture.output(r2 <- build_seg_recommendation_section(
    list(recommendation = list(reason = "no k")), "#CC9900"))

  expect_null(r1)
  expect_null(r2)
  expect_true(any(grepl("skipped", out1, ignore.case = TRUE)))
  expect_true(any(grepl("skipped", out2, ignore.case = TRUE)))
})

test_that("a metrics column with no data is named on the console, not just dropped (M5)", {
  skip_if_not(exists("build_seg_exploration_metrics_table", mode = "function"),
              "exploration report layer not loaded")

  out <- capture.output(build_seg_exploration_metrics_table(
    list(metrics_df = .explore_metrics_df())))

  # Nothing in the module computes Calinski-Harabasz or Davies-Bouldin for a
  # run: calculate_separation_metrics() has no callers. The table cannot show
  # them, and should say which columns it left out rather than quietly
  # presenting a narrower table as if that were all there is.
  joined <- paste(out, collapse = " ")
  expect_true(grepl("Calinski|CH", joined))
})


# ------------------------------------------------------------------------------
# Combined mode
# ------------------------------------------------------------------------------

.combined_html_data <- function(ch = NA_real_) {
  one <- function(sil, bss) list(
    diagnostics = list(avg_silhouette = sil, betweenss_totss = bss, ch_index = ch),
    segment_sizes = data.frame(n = c(120, 180), pct = c(40, 60))
  )
  list(kmeans = one(0.51, 0.46), hclust = one(0.44, 0.41))
}

test_that("a comparison column no method can fill is left out, not printed as dashes (M5)", {
  skip_if_not(exists("build_seg_method_comparison_table", mode = "function"),
              "combined report layer not loaded")

  # Nothing in the module computes Calinski-Harabasz for a run. The column
  # read diag$ch_index, which the transformer never writes, so every combined
  # report showed a CH column of dashes: a metric the reader assumes was
  # weighed and was not.
  out <- capture.output(html <- as.character(
    build_seg_method_comparison_table(.combined_html_data(ch = NA_real_))))

  expect_false(grepl("CH Index", html, fixed = TRUE))
  expect_true(grepl("Avg Silhouette", html, fixed = TRUE))
  expect_true(any(grepl("CH Index", out, fixed = TRUE)))
})

test_that("a comparison column with real values is kept (M5)", {
  skip_if_not(exists("build_seg_method_comparison_table", mode = "function"),
              "combined report layer not loaded")

  html <- as.character(build_seg_method_comparison_table(.combined_html_data(ch = 812.4)))

  expect_true(grepl("CH Index", html, fixed = TRUE))
  expect_true(grepl("812.4", html, fixed = TRUE))
})

test_that("a method dropped from the combined run is named in the REPORT (M5)", {
  html <- as.character(build_seg_combined_skipped_note(
    c("Method 'gmm': no results found, skipping.")))

  expect_true(grepl("gmm", html, fixed = TRUE))
  # The console note vanishes when the terminal closes. The file is what the
  # client keeps, so a comparison missing a method has to say so in itself.
  expect_true(grepl("not included|skipped", html, ignore.case = TRUE))
})

test_that("a clean combined run adds no note (M5)", {
  expect_null(build_seg_combined_skipped_note(character(0)))
  expect_null(build_seg_combined_skipped_note(NULL))
})

test_that("the skipped-methods note actually reaches the rendered panel (M5)", {
  # Testing the builder alone would prove the note exists, not that anyone
  # shows it. This runs the panel that assembles the comparison tab.
  skip_if_not(exists(".build_seg_comparison_panel", mode = "function"),
              "combined report layer not loaded")

  content <- list(
    table = NULL, chart = NULL, agreement = NULL,
    skipped = build_seg_combined_skipped_note(
      "Method 'gmm': no results found, skipping.")
  )
  html <- as.character(.build_seg_comparison_panel(
    content, .combined_html_data(), "#323367", "#CC9900"))

  expect_true(grepl("gmm", html, fixed = TRUE))
  expect_true(grepl("Not included in this comparison", html, fixed = TRUE))
})
