# ==============================================================================
# TESTS: sampling_labels.R — Sampling-Method-Aware Terminology
# ==============================================================================
# Verifies that get_sampling_labels() returns the correct terminology for each
# sampling method, that fallback/edge cases work, and that the labels are used
# correctly in HTML and Excel output.
# ==============================================================================

# ==============================================================================
# 1. CORE LABEL HELPER
# ==============================================================================

test_that("get_sampling_labels returns standard labels for probability designs", {
  for (method in c("Random", "Stratified", "Cluster", "Census")) {
    labels <- get_sampling_labels(method)
    expect_true(labels$is_probability, info = paste("method:", method))
    expect_equal(labels$interval_name, "Confidence Interval", info = method)
    expect_equal(labels$interval_abbrev, "CI", info = method)
    expect_equal(labels$moe_name, "Margin of Error", info = method)
    expect_equal(labels$moe_abbrev, "MOE", info = method)
    expect_equal(labels$halfwidth_name, "Half-Width", info = method)
    expect_equal(labels$precision_term, "margin of error", info = method)
    expect_equal(labels$interval_term, "confidence interval", info = method)
    expect_equal(labels$report_title, "Turas Confidence Analysis", info = method)
    expect_equal(labels$badge_text_fmt, "%d%% Confidence", info = method)
    expect_equal(labels$overview_title, "Confidence Interval Overview", info = method)
  }
})

test_that("get_sampling_labels returns softened labels for non-probability designs", {
  for (method in c("Quota", "Online_Panel", "Self_Selected", "Not_Specified")) {
    labels <- get_sampling_labels(method)
    expect_false(labels$is_probability, info = paste("method:", method))
    expect_equal(labels$interval_name, "Stability Interval", info = method)
    expect_equal(labels$interval_abbrev, "SI", info = method)
    expect_equal(labels$moe_name, "Precision Estimate", info = method)
    expect_equal(labels$moe_abbrev, "PE", info = method)
    expect_equal(labels$halfwidth_name, "Precision Estimate", info = method)
    expect_equal(labels$precision_term, "precision range", info = method)
    expect_equal(labels$interval_term, "stability interval", info = method)
    expect_equal(labels$report_title, "Turas Precision Analysis", info = method)
    expect_equal(labels$badge_text_fmt, "%d%% Stability", info = method)
    expect_equal(labels$overview_title, "Stability Interval Overview", info = method)
  }
})

test_that("get_sampling_labels maps config values to correct spec keys", {
  expect_equal(get_sampling_labels("Random")$sampling_method_normalised, "random")
  expect_equal(get_sampling_labels("Stratified")$sampling_method_normalised, "stratified")
  expect_equal(get_sampling_labels("Cluster")$sampling_method_normalised, "cluster")
  expect_equal(get_sampling_labels("Census")$sampling_method_normalised, "census")
  expect_equal(get_sampling_labels("Quota")$sampling_method_normalised, "quota")
  expect_equal(get_sampling_labels("Online_Panel")$sampling_method_normalised, "panel")
  expect_equal(get_sampling_labels("Self_Selected")$sampling_method_normalised, "convenience")
  expect_equal(get_sampling_labels("Not_Specified")$sampling_method_normalised, "not_specified")
})

test_that("get_sampling_labels handles NULL/NA/empty gracefully", {
  # All should fall back to Not_Specified (softened labels)
  for (input in list(NULL, NA, "", "  ")) {
    labels <- get_sampling_labels(input)
    expect_false(labels$is_probability, info = paste("input:", deparse(input)))
    expect_equal(labels$sampling_method_normalised, "not_specified",
                 info = paste("input:", deparse(input)))
    expect_equal(labels$interval_abbrev, "SI",
                 info = paste("input:", deparse(input)))
  }
})

test_that("get_sampling_labels handles unrecognised values as not_specified", {
  labels <- get_sampling_labels("SomeUnknownMethod")
  expect_equal(labels$sampling_method_normalised, "not_specified")
  expect_false(labels$is_probability)
  expect_equal(labels$interval_abbrev, "SI")
})

test_that("get_sampling_labels with no arguments returns softened labels", {
  labels <- get_sampling_labels()
  expect_false(labels$is_probability)
  expect_equal(labels$interval_abbrev, "SI")
})

test_that("CLUSTER_WARNING_HTML constant is defined and well-formed", {
  expect_true(exists("CLUSTER_WARNING_HTML"))
  expect_true(is.character(CLUSTER_WARNING_HTML))
  expect_true(nzchar(CLUSTER_WARNING_HTML))
  expect_true(grepl("Clustering not adjusted", CLUSTER_WARNING_HTML))
  expect_true(grepl("ci-callout-warning", CLUSTER_WARNING_HTML))
})


# ==============================================================================
# 2. HTML REPORT INTEGRATION — SUMMARY TABLE HEADERS
# ==============================================================================

test_that("build_ci_summary_table uses labels for column headers", {
  skip_if_not(exists("build_ci_summary_table", mode = "function"),
              "build_ci_summary_table not available")

  # Create minimal question data
  questions <- list(
    Q1 = list(
      question_id = "Q1", type = "proportion",
      estimate = 0.5, ci_lower = 0.4, ci_upper = 0.6, ci_width = 0.2,
      n_eff = 100, quality = list(badge = "good", text = "Good")
    )
  )

  # With probability labels
  prob_labels <- get_sampling_labels("Random")
  html_prob <- build_ci_summary_table(questions, labels = prob_labels)
  expect_true(grepl("CI Lower", html_prob), info = "probability design should use CI")

  # With non-probability labels
  np_labels <- get_sampling_labels("Online_Panel")
  html_np <- build_ci_summary_table(questions, labels = np_labels)
  expect_true(grepl("SI Lower", html_np), info = "non-probability design should use SI")
})


# ==============================================================================
# 3. HTML REPORT INTEGRATION — DETAIL TABLE HEADERS
# ==============================================================================

test_that("build_proportion_detail_table uses labels for MOE header", {
  skip_if_not(exists("build_proportion_detail_table", mode = "function"),
              "build_proportion_detail_table not available")

  results <- list(
    moe_normal = list(lower = 0.4, upper = 0.6, moe = 0.1)
  )

  prob_html <- build_proportion_detail_table(results, 0.95,
                                              labels = get_sampling_labels("Random"))
  expect_true(grepl("MOE", prob_html))
  expect_false(grepl(">PE<", prob_html))

  np_html <- build_proportion_detail_table(results, 0.95,
                                            labels = get_sampling_labels("Online_Panel"))
  expect_true(grepl(">PE<", np_html))
})

test_that("build_mean_detail_table uses labels for Half-Width header", {
  skip_if_not(exists("build_mean_detail_table", mode = "function"),
              "build_mean_detail_table not available")

  results <- list(
    t_dist = list(lower = 3.5, upper = 4.5, se = 0.2, df = 99)
  )

  prob_html <- build_mean_detail_table(results, 0.95,
                                        labels = get_sampling_labels("Stratified"))
  expect_true(grepl("Half-Width", prob_html))

  np_html <- build_mean_detail_table(results, 0.95,
                                      labels = get_sampling_labels("Quota"))
  expect_true(grepl("Precision Estimate", np_html))
})

test_that("build_nps_detail_table uses labels for MOE header", {
  skip_if_not(exists("build_nps_detail_table", mode = "function"),
              "build_nps_detail_table not available")

  results <- list(
    bootstrap = list(lower = -10, upper = 30, nps = 10)
  )

  prob_html <- build_nps_detail_table(results, 0.95,
                                       labels = get_sampling_labels("Random"))
  expect_true(grepl("MOE", prob_html))

  np_html <- build_nps_detail_table(results, 0.95,
                                     labels = get_sampling_labels("Self_Selected"))
  expect_true(grepl(">PE<", np_html))
})


# ==============================================================================
# 4. HTML PAGE BUILDER — TITLE, BADGE, OVERVIEW
# ==============================================================================

test_that("build_ci_header adapts title and badge to sampling method", {
  skip_if_not(exists("build_ci_header", mode = "function"),
              "build_ci_header not available")

  summary <- list(
    project_name = "Test Project",
    n_total = 500, n_questions = 3,
    confidence_level = 0.95, is_weighted = FALSE,
    generated = Sys.time(), sampling_method = "Random"
  )
  config <- list()

  # Probability design
  prob_labels <- get_sampling_labels("Random")
  header_prob <- build_ci_header(summary, "#1e3a5f", config, labels = prob_labels)
  expect_true(grepl("Turas Confidence Analysis", header_prob))
  expect_true(grepl("95% Confidence", header_prob))

  # Non-probability design
  np_labels <- get_sampling_labels("Online_Panel")
  header_np <- build_ci_header(summary, "#1e3a5f", config, labels = np_labels)
  expect_true(grepl("Turas Precision Analysis", header_np))
  expect_true(grepl("95% Stability", header_np))
})

test_that("build_ci_summary_panel uses correct overview card title", {
  skip_if_not(exists("build_ci_summary_panel", mode = "function"),
              "build_ci_summary_panel not available")
  skip_if_not(exists("build_ci_forest_plot", mode = "function"),
              "build_ci_forest_plot not available")

  html_data <- list(
    summary = list(
      n_total = 200, n_effective = 180, n_questions = 1,
      deff = 1.1, is_weighted = FALSE, confidence_level = 0.95,
      generated = Sys.time(), sampling_method = "Random"
    ),
    study_level = NULL,
    questions = list(
      Q1 = list(
        question_id = "Q1", type = "proportion",
        estimate = 0.5, ci_lower = 0.4, ci_upper = 0.6, ci_width = 0.2,
        n_eff = 200, quality = list(badge = "good", text = "Good")
      )
    )
  )

  forest_svg <- tryCatch(
    build_ci_forest_plot(html_data$questions, "#1e3a5f"),
    error = function(e) "<svg>mock</svg>"
  )

  tables <- list(summary = "<table>mock</table>")
  charts <- list(forest_plot = forest_svg)

  # Probability
  prob_labels <- get_sampling_labels("Random")
  panel_prob <- build_ci_summary_panel(html_data, tables, charts, labels = prob_labels)
  expect_true(grepl("Confidence Interval Overview", panel_prob))

  # Non-probability
  np_labels <- get_sampling_labels("Self_Selected")
  panel_np <- build_ci_summary_panel(html_data, tables, charts, labels = np_labels)
  expect_true(grepl("Stability Interval Overview", panel_np))
})


# ==============================================================================
# 5. CLUSTER WARNING
# ==============================================================================

test_that("build_ci_details_panel injects cluster warning only for cluster samples", {
  skip_if_not(exists("build_ci_details_panel", mode = "function"),
              "build_ci_details_panel not available")

  html_data <- list(
    methodology = list(confidence_level = 0.95),
    questions = list(
      Q1 = list(
        question_id = "Q1", type = "proportion",
        callout = "<div>Test callout</div>",
        quality = list(badge = "good", text = "Good"),
        n_eff = 200,
        results = list(
          moe_normal = list(lower = 0.4, upper = 0.6, moe = 0.1)
        )
      )
    )
  )

  tables <- list(detail_Q1 = "<table>mock</table>")
  charts <- list(methods_Q1 = "<svg>mock</svg>")

  # Cluster: warning should appear
  cluster_labels <- get_sampling_labels("Cluster")
  panel_cluster <- build_ci_details_panel(html_data, tables, charts, "#1e3a5f",
                                           labels = cluster_labels)
  expect_true(grepl("Clustering not adjusted", panel_cluster),
              info = "Cluster sample should have cluster warning")

  # Random: no warning
  random_labels <- get_sampling_labels("Random")
  panel_random <- build_ci_details_panel(html_data, tables, charts, "#1e3a5f",
                                          labels = random_labels)
  expect_false(grepl("Clustering not adjusted", panel_random),
               info = "Random sample should NOT have cluster warning")

  # Non-probability: no warning
  panel_np <- build_ci_details_panel(html_data, tables, charts, "#1e3a5f",
                                      labels = get_sampling_labels("Online_Panel"))
  expect_false(grepl("Clustering not adjusted", panel_np),
               info = "Non-probability sample should NOT have cluster warning")
})


# ==============================================================================
# 6. DATA TRANSFORMER — CALLOUT TEXTS
# ==============================================================================

test_that("build_sampling_note returns correct callout for each method", {
  skip_if_not(exists("build_sampling_note", mode = "function"),
              "build_sampling_note not available")

  # build_sampling_note uses config-level values (e.g. "Random", "Online_Panel")
  config_values <- c("Random", "Stratified", "Cluster", "Census",
                      "Online_Panel", "Quota", "Self_Selected", "Not_Specified")

  # Check each method returns a non-empty string with correct class
  for (method in config_values) {
    note <- build_sampling_note(method)
    expect_true(is.character(note) && nzchar(note),
                info = paste("method:", method))
    expect_true(grepl("ci-callout-sampling", note),
                info = paste("method:", method, "should have ci-callout-sampling class"))
  }

  # Specific content checks
  random_note <- build_sampling_note("Random")
  expect_true(grepl("gold standard", random_note))

  cluster_note <- build_sampling_note("Cluster")
  expect_true(grepl("clustering", cluster_note, ignore.case = TRUE))

  panel_note <- build_sampling_note("Online_Panel")
  expect_true(grepl("pre-recruited", panel_note))

  not_specified_note <- build_sampling_note("Not_Specified")
  expect_true(grepl("not recorded", not_specified_note))
})
