# ==============================================================================
# SEGMENT MODULE TESTS - HTML REPORT ROBUSTNESS (production-hardening audit)
# ==============================================================================
# Regression coverage for the "section silently drops" bug class found in the
# v1-hardening review: a chart/section crashes (and the orchestrator swallows
# the error to NULL) on realistic-but-imperfect input.
# ==============================================================================

# ---- C1: chart builders must not crash when question_labels is partial ------
# (a named vector covering only SOME clustering variables). Previously
# `ql[[v]]` on a missing name threw "subscript out of bounds" and the chart
# silently vanished.
test_that("chart builders survive a partial question_labels vector", {
  skip_if_not(exists("build_seg_importance_chart", mode = "function"), "html report not loaded")
  partial <- c(q1 = "Quality", q2 = "Service")   # q3 deliberately missing

  vi <- data.frame(variable = c("q1", "q2", "q3"), eta_squared = c(.3, .2, .1),
                   importance_pct = c(50, 33, 17), rank = 1:3, stringsAsFactors = FALSE)
  imp <- build_seg_importance_chart(
    list(variable_importance = vi, question_labels = partial), "#323367")
  expect_true(nchar(as.character(imp)) > 50)   # rendered, did not crash to ""

  centers <- matrix(c(8, 3, 5, 4, 6, 2, 7, 5, 3), nrow = 3,
                    dimnames = list(NULL, c("q1", "q2", "q3")))
  heat <- build_seg_heatmap_chart(
    list(centers = centers, k = 3, segment_names = paste("Segment", 1:3),
         question_labels = partial), "#323367", "#CC9900")
  expect_true(nchar(as.character(heat)) > 50)

  if (exists("build_seg_golden_questions_chart", mode = "function")) {
    gq <- list(top_questions = data.frame(variable = c("q1", "q2", "q3"),
                 importance = c(20, 15, 10), pct_of_total = c(44, 33, 22),
                 rank = 1:3, stringsAsFactors = FALSE))
    g <- build_seg_golden_questions_chart(
      list(golden_questions = gq, question_labels = partial), "#323367")
    expect_true(nchar(as.character(g)) > 20)
  }
})


# ---- C2: heatmap survives a segment_names vector shorter than k -------------
test_that("heatmap does not produce NA labels when segment_names is short", {
  skip_if_not(exists("build_seg_heatmap_chart", mode = "function"), "html report not loaded")
  centers <- matrix(c(8, 3, 5, 4, 6, 2), nrow = 3, dimnames = list(NULL, c("q1", "q2")))
  heat <- as.character(build_seg_heatmap_chart(
    list(centers = centers, k = 3, segment_names = c("Champions", "At-risk")),  # only 2 of 3
    "#323367", "#CC9900"))
  expect_true(nchar(heat) > 50)
  expect_false(grepl(">NA<", heat, fixed = TRUE))   # no NA axis label leaked
})


# ---- B2: generate_headline is NA-safe (a segment with an all-NA variable) ---
test_that("generate_headline does not crash on NA means", {
  skip_if_not(exists("generate_headline", mode = "function"), "cards not loaded")
  stats <- list(segment_name = "Segment 1", means = c(NA, 5, 6),
                overall_means = c(5, 5, 5), diffs = c(q1 = NA, q2 = 0, q3 = 1),
                defining_vars = c("q1", "q2"))
  h <- generate_headline(stats, NULL)
  expect_true(is.character(h) && nzchar(h))      # a sensible string, no crash
})


# ---- A1: the About panel reports the real silhouette, not 0.000 -------------
test_that("About section method summary shows the actual silhouette", {
  skip_if_not(exists("build_seg_about_section", mode = "function"), "html report not loaded")
  hd <- list(method = "kmeans", k = 4L, n_observations = 300L,
             analysis_name = "Test",
             variable_importance = data.frame(variable = c("q1", "q2"),
               importance_pct = c(60, 40), rank = 1:2, stringsAsFactors = FALSE),
             diagnostics = list(method = "kmeans", k = 4L, n_observations = 300L,
               n_variables = 2L, avg_silhouette = 0.512))
  about <- as.character(build_seg_about_section(list(report_title = "Test"), hd))
  expect_true(grepl("0.512", about, fixed = TRUE))                 # real value present
  expect_false(grepl("Average silhouette: 0.000", about, fixed = TRUE))  # not the bug value
})


# ---- D2: assignments file never carries NA segment names --------------------
test_that("export_segment_assignments labels NA/outlier clusters, never NA", {
  skip_if_not(exists("export_segment_assignments", mode = "function"), "output not loaded")
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not installed")
  data <- data.frame(respondent_id = paste0("R", 1:6), q1 = 1:6, stringsAsFactors = FALSE)
  clusters <- c(1L, 2L, 1L, NA, 2L, 1L)                 # row 4 = flagged outlier
  out <- tempfile(fileext = ".xlsx"); on.exit(unlink(out), add = TRUE)
  export_segment_assignments(data, clusters, c("Champions", "At-risk"),
                             "respondent_id", out)
  asg <- openxlsx::read.xlsx(out, sheet = "Segment_Assignments")
  expect_false(any(is.na(asg$segment_name)))            # no NA names leaked
  expect_true("Unassigned" %in% asg$segment_name)       # outlier labelled
})
