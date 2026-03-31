# ==============================================================================
# SEGMENT MODULE - HTML REPORT TESTS
# ==============================================================================
# Tests for the HTML report pipeline: data transformation, chart building,
# table building, page assembly, and report generation.
# ==============================================================================

# Helper: run a small clustering and profiling to get results for report
.make_report_fixtures <- function(n = 100, k = 3, method = "kmeans") {
  td <- generate_segment_test_data(n = n, k_true = k, n_vars = 5, seed = 42)
  data <- td$data
  clustering_vars <- td$clustering_vars

  config <- generate_test_config(td, method = method, k_fixed = k)
  config$scale_max <- 10
  config$report_title <- "Test Segmentation Report"
  config$project_name <- "Test Project"
  config$analyst_name <- "Test Analyst"
  config$description <- "Test description"
  config$brand_colour <- "#323367"
  config$accent_colour <- "#CC9900"

  guard <- segment_guard_init()

  # Prepare data
  numeric_data <- data[, clustering_vars, drop = FALSE]
  for (col in clustering_vars) {
    med <- median(numeric_data[[col]], na.rm = TRUE)
    numeric_data[[col]][is.na(numeric_data[[col]])] <- med
  }
  scaled <- scale(numeric_data)

  data_list <- list(
    original_data = data,
    scaled_data = scaled,
    clustering_vars = clustering_vars,
    config = config,
    scale_params = list(
      center = attr(scaled, "scaled:center"),
      scale = attr(scaled, "scaled:scale")
    )
  )

  # Cluster
  cr <- run_clustering(data_list, config, guard)

  # Validate
  vm <- calculate_validation_metrics(scaled, cr, k)

  # Profile
  pr <- create_full_segment_profile(
    data = data,
    clusters = cr$clusters,
    clustering_vars = clustering_vars,
    profile_vars = config$profile_vars
  )

  # Vulnerability
  vuln <- tryCatch(
    calculate_vulnerability(
      scaled_data = scaled,
      clusters = cr$clusters,
      centers = cr$centers,
      k = k,
      method = method,
      confidence_threshold = 0.30
    ),
    error = function(e) NULL
  )

  list(
    cluster_result = cr,
    validation_metrics = vm,
    profile_result = pr,
    vulnerability = vuln,
    data_list = data_list,
    config = config,
    segment_names = paste("Segment", 1:k)
  )
}


# ==============================================================================
# DATA TRANSFORMER TESTS
# ==============================================================================

test_that("HTML report contains correct diagnostics info", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  expect_equal(result$status, "PASS")
  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Should contain segment size information
  expect_true(grepl("Segment 1", html_text, fixed = TRUE),
              info = "Report should contain segment names")
  # Should contain k=3 information
  expect_true(grepl("3", html_text, fixed = TRUE),
              info = "Report should contain k value")
  # Should contain method
  expect_true(grepl("K-Means", html_text, ignore.case = TRUE),
              info = "Report should contain method name")
})

test_that("HTML report contains variable importance with question reduction", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Variable importance section should be present
  expect_true(grepl("Variable Importance", html_text, fixed = TRUE),
              info = "Report should have variable importance section")

  # Question reduction analysis should be present
  expect_true(grepl("Question Reduction", html_text, fixed = TRUE),
              info = "Report should have question reduction analysis")
  expect_true(grepl("segment discrimination", html_text, ignore.case = TRUE),
              info = "Reduction analysis should mention segment discrimination")
})


# ==============================================================================
# FULL HTML REPORT GENERATION TESTS
# ==============================================================================

test_that("HTML report generates valid file for kmeans", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures(method = "kmeans")
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(file.info(output_path)$size > 1000,
              info = "HTML file should be non-trivial size")

  # Read and check basic content
  html_content <- readLines(output_path, warn = FALSE)
  html_text <- paste(html_content, collapse = "\n")

  expect_true(grepl("<!DOCTYPE html>", html_text, fixed = TRUE))
  expect_true(grepl("K-Means", html_text, ignore.case = TRUE),
              info = "Report should mention the clustering method")
  expect_true(grepl("Segment Profiles", html_text),
              info = "Report should have profiles section")
})

test_that("HTML report generates valid file for hclust", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures(method = "hclust")
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "hclust",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("Hierarchical", html_text, ignore.case = TRUE),
              info = "Report should mention hierarchical clustering")
})

test_that("HTML report contains green/red color coding", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Green for above-average (traditional)
  expect_true(grepl("#dcfce7", html_text, fixed = TRUE),
              info = "CSS should use green for above-average (seg-td-high)")
  # Red for below-average (traditional)
  expect_true(grepl("#fee2e2", html_text, fixed = TRUE),
              info = "CSS should use red for below-average (seg-td-low)")
  # CSS seg-td-high class should use green, not old blue
  expect_true(grepl("seg-td-high.*#dcfce7", html_text, perl = TRUE),
              info = "seg-td-high CSS class should use green, not blue")
})

test_that("HTML report contains pin buttons with emoji", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Pin buttons should use emoji, not SVG bookmark
  expect_true(grepl("seg-pin-btn", html_text, fixed = TRUE),
              info = "Report should have pin buttons")
  # Extract pin button markup and verify it uses emoji (pushpin), not SVG icons
  pin_btn_matches <- regmatches(html_text,
    gregexpr('class="seg-pin-btn"[^>]*>[^<]*<', html_text, perl = TRUE))[[1]]
  expect_true(length(pin_btn_matches) > 0,
              info = "Should find seg-pin-btn elements")
  has_svg_in_pins <- any(grepl("viewBox", pin_btn_matches, fixed = TRUE))
  expect_false(has_svg_in_pins,
               info = "Pin buttons should not use SVG bookmark icons")
})

test_that("HTML report overlap chart uses similarity percentages", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Overlap section should contain the overlap table
  expect_true(grepl("seg-overlap-table", html_text, fixed = TRUE),
              info = "Report should have overlap table")
  # Should contain percentage values in table cells
  expect_true(grepl('[0-9]+%', html_text),
              info = "Overlap table should show similarity percentages")
})

test_that("HTML report contains question reduction analysis", {
  skip_if_not(exists("generate_segment_html_report", mode = "function"),
              "HTML report pipeline not loaded")

  fix <- .make_report_fixtures()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path), add = TRUE)

  results <- list(
    mode = "final",
    method = "kmeans",
    cluster_result = fix$cluster_result,
    validation_metrics = fix$validation_metrics,
    profile_result = fix$profile_result,
    vulnerability = fix$vulnerability,
    segment_names = fix$segment_names,
    data_list = fix$data_list,
    config = fix$config
  )

  result <- generate_segment_html_report(
    results = results,
    config = fix$config,
    output_path = output_path
  )

  html_text <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("Question Reduction", html_text, fixed = TRUE),
              info = "Report should have question reduction analysis")
  expect_true(grepl("segment discrimination", html_text, ignore.case = TRUE),
              info = "Reduction analysis should mention segment discrimination")
})
