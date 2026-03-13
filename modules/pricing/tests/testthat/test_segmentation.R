# ==============================================================================
# TURAS PRICING MODULE - SEGMENTATION TESTS
# ==============================================================================

test_that("run_segmented_analysis handles VW method", {
  skip_if(!exists("run_segmented_analysis", mode = "function"),
          "run_segmented_analysis not available")
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  vw_data <- generate_vw_data(n = 300)
  seg_data <- generate_segmented_data(n = 300)
  data <- cbind(vw_data, segment = seg_data$segment)

  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    segmentation = list(
      segment_column = "segment",
      min_segment_n = 30,
      include_total = TRUE
    ),
    currency_symbol = "$"
  )

  result <- run_segmented_analysis(data, config, method = "van_westendorp")

  expect_true(is.list(result))
  expect_true(!is.null(result$total_results))
  expect_true(!is.null(result$segment_results))
  expect_true(length(result$segment_results) > 0)
})

test_that("run_segmented_analysis builds comparison table", {
  skip_if(!exists("run_segmented_analysis", mode = "function"),
          "run_segmented_analysis not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  vw_data <- generate_vw_data(n = 300)
  seg_data <- generate_segmented_data(n = 300)
  data <- cbind(vw_data, segment = seg_data$segment)

  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    segmentation = list(
      segment_column = "segment",
      min_segment_n = 30,
      include_total = TRUE
    ),
    currency_symbol = "$"
  )

  result <- run_segmented_analysis(data, config, method = "van_westendorp")

  expect_true(!is.null(result$comparison_table))
  ct <- result$comparison_table
  expect_true(is.data.frame(ct))
  expect_true(nrow(ct) > 0)
})

test_that("run_segmented_analysis skips small segments", {
  skip_if(!exists("run_segmented_analysis", mode = "function"),
          "run_segmented_analysis not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  vw_data <- generate_vw_data(n = 100)
  segments <- c(rep("Large", 90), rep("Small", 10))
  data <- cbind(vw_data[1:100, ], segment = segments)

  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    segmentation = list(
      segment_column = "segment",
      min_segment_n = 30,
      include_total = TRUE
    ),
    currency_symbol = "$"
  )

  result <- run_segmented_analysis(data, config, method = "van_westendorp")

  expect_true(is.list(result))
  # Small segment (n=10) should be skipped
  if (!is.null(result$segment_results)) {
    expect_true(!"Small" %in% names(result$segment_results))
  }
})

test_that("run_segmented_analysis refuses missing segment column", {
  skip_if(!exists("run_segmented_analysis", mode = "function"),
          "run_segmented_analysis not available")

  data <- generate_vw_data(n = 100)

  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    segmentation = list(
      segment_column = "nonexistent_column",
      min_segment_n = 30
    ),
    currency_symbol = "$"
  )

  expect_error(
    run_segmented_analysis(data, config, method = "van_westendorp"),
    "DATA_SEGMENT|Segment.*Not Found"
  )
})

test_that("generate_segment_insights returns insights", {
  skip_if(!exists("generate_segment_insights", mode = "function"),
          "generate_segment_insights not available")

  comparison <- data.frame(
    segment = c("Price Sensitive", "Mainstream", "Premium"),
    OPP = c(30, 45, 65),
    IDP = c(40, 55, 80),
    PMC = c(15, 25, 40),
    PME = c(55, 75, 100),
    stringsAsFactors = FALSE
  )

  result <- generate_segment_insights(comparison, method = "van_westendorp")

  expect_true(is.list(result) || is.character(result))
})
