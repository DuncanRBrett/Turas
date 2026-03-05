# Tests for executive summary generator (12_executive_summary.R)
# Part of Turas Segment Module v11.0 test suite
#
# Tests generate_segment_executive_summary(), .detect_dominant_segment(),
# and format_segment_executive_summary().

# ==============================================================================
# Helper: create minimal inputs for executive summary
# ==============================================================================

.make_summary_fixtures <- function(k = 3, n = 300, method = "kmeans",
                                    silhouette = 0.45, segment_pcts = NULL) {
  set.seed(42)

  if (is.null(segment_pcts)) {
    # Roughly equal segments
    sizes <- rep(floor(n / k), k)
    sizes[k] <- n - sum(sizes[-k])
  } else {
    sizes <- round(segment_pcts / 100 * n)
    sizes[k] <- n - sum(sizes[-k])
  }

  clusters <- unlist(lapply(seq_len(k), function(i) rep(i, sizes[i])))

  # Build cluster_result
  p <- 5
  centers <- matrix(rnorm(k * p), nrow = k, ncol = p)
  colnames(centers) <- paste0("q", seq_len(p))

  cluster_result <- list(
    clusters = as.integer(clusters),
    k = k,
    centers = centers,
    method = method,
    model = list(),
    method_info = list(algorithm = "Hartigan-Wong", nstart = 25)
  )

  # Build validation_metrics
  validation_metrics <- list(
    avg_silhouette = silhouette,
    betweenss_totss = 0.65
  )

  # Build a minimal profile_result
  overall_means <- colMeans(centers)
  profile_df <- data.frame(
    Variable = paste0("q", seq_len(p)),
    Overall = overall_means,
    stringsAsFactors = FALSE
  )
  for (i in seq_len(k)) {
    profile_df[[paste0("Segment_", i)]] <- centers[i, ]
  }
  # Add an eta_sq column for differentiating variables
  profile_df$eta_sq <- c(0.45, 0.30, 0.20, 0.10, 0.05)

  profile_result <- list(
    clustering_profile = profile_df
  )

  segment_names <- paste0("Segment ", seq_len(k))

  config <- list(
    method = method,
    k_fixed = k,
    mode = "final"
  )

  list(
    cluster_result = cluster_result,
    validation_metrics = validation_metrics,
    profile_result = profile_result,
    segment_names = segment_names,
    config = config,
    k = k,
    n = n
  )
}


# ==============================================================================
# generate_segment_executive_summary()
# ==============================================================================

test_that("generate_segment_executive_summary() returns all required fields", {
  # Arrange
  fx <- .make_summary_fixtures()

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_true(is.list(summary))
  expect_true("headline" %in% names(summary))
  expect_true("key_findings" %in% names(summary))
  expect_true("quality_assessment" %in% names(summary))
  expect_true("segment_descriptions" %in% names(summary))
  expect_true("warnings" %in% names(summary))
  expect_true("recommendations" %in% names(summary))
})

test_that("headline mentions method and k", {
  # Arrange
  fx <- .make_summary_fixtures(k = 4, method = "kmeans")

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_true(grepl("4", summary$headline))
  # K-means should appear as "K-means" in headline

  expect_true(grepl("means", summary$headline, ignore.case = TRUE) ||
              grepl("kmeans", summary$headline, ignore.case = TRUE))
})

test_that("headline mentions hclust method correctly", {
  # Arrange
  fx <- .make_summary_fixtures(k = 3, method = "hclust")

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_true(grepl("hierarchical", summary$headline, ignore.case = TRUE))
})

test_that("key_findings is non-empty character vector", {
  # Arrange
  fx <- .make_summary_fixtures()

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_type(summary$key_findings, "character")
  expect_true(length(summary$key_findings) >= 1)
  # Each finding should be a non-empty string
  for (f in summary$key_findings) {
    expect_true(nchar(f) > 0)
  }
})

test_that("quality_assessment mentions silhouette", {
  # Arrange
  fx <- .make_summary_fixtures(silhouette = 0.55)

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_type(summary$quality_assessment, "character")
  expect_true(grepl("silhouette", summary$quality_assessment, ignore.case = TRUE))
  expect_true(grepl("0.550", summary$quality_assessment))
})

test_that("segment_descriptions has length k", {
  # Arrange - k = 4
  fx <- .make_summary_fixtures(k = 4)

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_length(summary$segment_descriptions, 4)
  expect_type(summary$segment_descriptions, "character")
})

test_that("generate_segment_executive_summary() refuses on NULL cluster_result", {
  # Arrange
  fx <- .make_summary_fixtures()

  # Act & Assert
  expect_error(
    generate_segment_executive_summary(
      cluster_result = NULL,
      validation_metrics = fx$validation_metrics,
      profile_result = fx$profile_result,
      segment_names = fx$segment_names,
      config = fx$config
    ),
    class = "turas_refusal"
  )
})

test_that("low silhouette produces warning in summary", {
  # Arrange
  fx <- .make_summary_fixtures(silhouette = 0.15)

  # Act
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Assert
  expect_true(length(summary$warnings) >= 1)
  expect_true(any(grepl("silhouette", summary$warnings, ignore.case = TRUE)))
})


# ==============================================================================
# .detect_dominant_segment()
# ==============================================================================

test_that(".detect_dominant_segment() returns warning when segment > 40%", {
  # Arrange
  seg_pcts <- c(55, 25, 20)
  segment_names <- c("Loyalists", "Switchers", "Detractors")

  # Act
  result <- .detect_dominant_segment(seg_pcts, segment_names, threshold = 40)

  # Assert
  expect_false(is.null(result))
  expect_type(result, "character")
  expect_true(grepl("Loyalists", result))
  expect_true(grepl("55", result))
})

test_that(".detect_dominant_segment() returns NULL when no dominant segment", {
  # Arrange
  seg_pcts <- c(35, 35, 30)
  segment_names <- c("Seg A", "Seg B", "Seg C")

  # Act
  result <- .detect_dominant_segment(seg_pcts, segment_names, threshold = 40)

  # Assert
  expect_null(result)
})

test_that(".detect_dominant_segment() respects custom threshold", {
  # Arrange
  seg_pcts <- c(35, 35, 30)
  segment_names <- c("Seg A", "Seg B", "Seg C")

  # Act - lower threshold
  result <- .detect_dominant_segment(seg_pcts, segment_names, threshold = 30)

  # Assert - 35% > 30%, so should detect
  expect_false(is.null(result))
})

test_that(".detect_dominant_segment() uses fallback names when segment_names is NULL", {
  # Arrange
  seg_pcts <- c(50, 30, 20)

  # Act
  result <- .detect_dominant_segment(seg_pcts, segment_names = NULL, threshold = 40)

  # Assert
  expect_false(is.null(result))
  expect_true(grepl("Segment 1", result))
})


# ==============================================================================
# format_segment_executive_summary() - text format
# ==============================================================================

test_that("format_segment_executive_summary() text format works", {
  # Arrange
  fx <- .make_summary_fixtures()
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Act
  text_output <- format_segment_executive_summary(summary, format = "text")

  # Assert
  expect_type(text_output, "character")
  expect_true(length(text_output) > 1)
  expect_true(any(grepl("EXECUTIVE SUMMARY", text_output)))
  expect_true(any(grepl("KEY FINDINGS", text_output)))
  expect_true(any(grepl("QUALITY ASSESSMENT", text_output)))
  expect_true(any(grepl("RECOMMENDATIONS", text_output)))
})

test_that("format_segment_executive_summary() text includes segment descriptions", {
  # Arrange
  fx <- .make_summary_fixtures()
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Act
  text_output <- format_segment_executive_summary(summary, format = "text")

  # Assert
  expect_true(any(grepl("SEGMENT DESCRIPTIONS", text_output)))
})


# ==============================================================================
# format_segment_executive_summary() - html format
# ==============================================================================

test_that("format_segment_executive_summary() html format works", {
  # Arrange
  fx <- .make_summary_fixtures()
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Act
  html_output <- format_segment_executive_summary(summary, format = "html")

  # Assert
  expect_type(html_output, "character")
  expect_length(html_output, 1)  # single HTML string
  expect_true(grepl("<div", html_output))
  expect_true(grepl("Executive Summary", html_output))
  expect_true(grepl("Key Findings", html_output))
  expect_true(grepl("Quality Assessment", html_output))
  expect_true(grepl("Recommendations", html_output))
  expect_true(grepl("</div>", html_output))
})

test_that("format_segment_executive_summary() html includes warnings section when present", {
  # Arrange - low silhouette to trigger warnings
  fx <- .make_summary_fixtures(silhouette = 0.10)
  summary <- generate_segment_executive_summary(
    cluster_result = fx$cluster_result,
    validation_metrics = fx$validation_metrics,
    profile_result = fx$profile_result,
    segment_names = fx$segment_names,
    config = fx$config
  )

  # Act
  html_output <- format_segment_executive_summary(summary, format = "html")

  # Assert
  expect_true(grepl("Warnings", html_output))
})

test_that("format_segment_executive_summary() handles NULL input gracefully", {
  # Act
  result <- format_segment_executive_summary(NULL, format = "text")

  # Assert
  expect_equal(result, "Executive summary not available.")
})

test_that("format_segment_executive_summary() handles non-list input gracefully", {
  # Act
  result <- format_segment_executive_summary("not a list", format = "text")

  # Assert
  expect_equal(result, "Executive summary not available.")
})
