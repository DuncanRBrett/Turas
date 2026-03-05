# ==============================================================================
# TEST SUITE: Segment Comparison (07_segment_comparison.R)
# ==============================================================================
# Tests for build_importance_comparison_matrix(), classify_drivers(),
# and generate_segment_insights().
# Part of Turas Key Driver Module Test Suite
# ==============================================================================

library(testthat)

context("Segment Comparison")

# ==============================================================================
# SETUP
# ==============================================================================

# Null-coalescing operator (may not be loaded in test context)
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Source test data generators
fixtures_path <- file.path(dirname(dirname(testthat::test_path())), "fixtures", "generate_test_data.R")
if (file.exists(fixtures_path)) {
  source(fixtures_path)
}

# Source the module under test (with TRS infrastructure)
trs_path <- file.path(dirname(dirname(dirname(dirname(testthat::test_path())))), "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

guard_path <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R", "00_guard.R")
if (file.exists(guard_path)) source(guard_path)

source_path <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R", "07_segment_comparison.R")
if (file.exists(source_path)) source(source_path)


# ==============================================================================
# HELPER: Build a simple segment results list for direct unit testing
# ==============================================================================

build_two_segment_results <- function() {
  list(
    Premium = data.frame(
      Driver = c("Price", "Quality", "Service", "Convenience"),
      Importance_Pct = c(35, 30, 20, 15),
      stringsAsFactors = FALSE
    ),
    Budget = data.frame(
      Driver = c("Price", "Quality", "Service", "Convenience"),
      Importance_Pct = c(50, 15, 25, 10),
      stringsAsFactors = FALSE
    )
  )
}

build_three_segment_results <- function() {
  list(
    Premium = data.frame(
      Driver = c("Price", "Quality", "Service", "Convenience", "Brand"),
      Importance_Pct = c(15, 35, 25, 15, 10),
      stringsAsFactors = FALSE
    ),
    Standard = data.frame(
      Driver = c("Price", "Quality", "Service", "Convenience", "Brand"),
      Importance_Pct = c(30, 25, 20, 15, 10),
      stringsAsFactors = FALSE
    ),
    Budget = data.frame(
      Driver = c("Price", "Quality", "Service", "Convenience", "Brand"),
      Importance_Pct = c(50, 10, 15, 20, 5),
      stringsAsFactors = FALSE
    )
  )
}


# ==============================================================================
# TESTS: build_importance_comparison_matrix()
# ==============================================================================

test_that("build_importance_comparison_matrix returns correct wide-format data.frame", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)

  expect_true(is.data.frame(mat))
  expect_true("Driver" %in% names(mat))
  expect_true("Mean_Pct" %in% names(mat))

  # Should have Pct and Rank columns for each segment
  expect_true("Premium_Pct" %in% names(mat))
  expect_true("Premium_Rank" %in% names(mat))
  expect_true("Budget_Pct" %in% names(mat))
  expect_true("Budget_Rank" %in% names(mat))
})

test_that("build_importance_comparison_matrix has one row per driver", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)

  # All drivers from both segments should appear
  all_drivers <- unique(unlist(lapply(seg_results, function(df) df$Driver)))
  expect_equal(nrow(mat), length(all_drivers))
  expect_true(all(all_drivers %in% mat$Driver))
})

test_that("build_importance_comparison_matrix sorts by Mean_Pct descending", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)

  # Mean_Pct should be in decreasing order
  expect_true(all(diff(mat$Mean_Pct) <= 0))
})

test_that("build_importance_comparison_matrix ranks are correct within segments", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)

  # In Budget segment, Price (50%) should be rank 1
  price_row <- mat[mat$Driver == "Price", ]
  expect_equal(price_row$Budget_Rank, 1L)

  # In Premium segment, Price (35%) should be rank 1
  expect_equal(price_row$Premium_Rank, 1L)
})

test_that("build_importance_comparison_matrix handles 3+ segments correctly", {
  seg_results <- build_three_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)

  expect_true(is.data.frame(mat))
  expect_equal(nrow(mat), 5)  # 5 drivers

  # Should have columns for all 3 segments
  expect_true("Premium_Pct" %in% names(mat))
  expect_true("Standard_Pct" %in% names(mat))
  expect_true("Budget_Pct" %in% names(mat))
  expect_true("Premium_Rank" %in% names(mat))
  expect_true("Standard_Rank" %in% names(mat))
  expect_true("Budget_Rank" %in% names(mat))

  # Mean_Pct should be the mean of the three segment Pct columns
  for (i in seq_len(nrow(mat))) {
    expected_mean <- mean(c(mat$Premium_Pct[i], mat$Standard_Pct[i], mat$Budget_Pct[i]))
    expect_equal(mat$Mean_Pct[i], expected_mean, tolerance = 0.01)
  }
})

test_that("build_importance_comparison_matrix handles drivers missing from some segments", {
  seg_results <- list(
    SegA = data.frame(
      Driver = c("Price", "Quality", "Service"),
      Importance_Pct = c(40, 35, 25),
      stringsAsFactors = FALSE
    ),
    SegB = data.frame(
      Driver = c("Price", "Quality", "Brand"),
      Importance_Pct = c(50, 30, 20),
      stringsAsFactors = FALSE
    )
  )

  mat <- build_importance_comparison_matrix(seg_results)

  # Should have 4 unique drivers
  expect_equal(nrow(mat), 4)
  expect_true("Service" %in% mat$Driver)
  expect_true("Brand" %in% mat$Driver)

  # Service should have NA for SegB
  service_row <- mat[mat$Driver == "Service", ]
  expect_true(is.na(service_row$SegB_Pct))
  expect_true(is.na(service_row$SegB_Rank))

  # Brand should have NA for SegA
  brand_row <- mat[mat$Driver == "Brand", ]
  expect_true(is.na(brand_row$SegA_Pct))
  expect_true(is.na(brand_row$SegA_Rank))
})


# ==============================================================================
# TESTS: classify_drivers()
# ==============================================================================

test_that("classify_drivers identifies Universal drivers (consistently top-ranked)", {
  # Build a matrix where Price is rank 1 across all segments
  seg_results <- list(
    SegA = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience"),
      Importance_Pct = c(40, 25, 15, 12, 8),
      stringsAsFactors = FALSE
    ),
    SegB = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience"),
      Importance_Pct = c(38, 27, 18, 10, 7),
      stringsAsFactors = FALSE
    ),
    SegC = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience"),
      Importance_Pct = c(35, 30, 20, 9, 6),
      stringsAsFactors = FALSE
    )
  )

  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3)

  expect_true(is.data.frame(classes))
  expect_true("Classification" %in% names(classes))
  expect_true("Description" %in% names(classes))

  # Price and Quality are consistently in top 3 across all segments
  price_class <- classes$Classification[classes$Driver == "Price"]
  quality_class <- classes$Classification[classes$Driver == "Quality"]
  expect_equal(price_class, "Universal")
  expect_equal(quality_class, "Universal")
})

test_that("classify_drivers identifies Segment-Specific drivers (high in one, low in others)", {
  # Build a matrix where Brand is #1 in SegA but low in SegB and SegC
  seg_results <- list(
    SegA = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience", "Speed"),
      Importance_Pct = c(15, 20, 10, 40, 10, 5),
      stringsAsFactors = FALSE
    ),
    SegB = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience", "Speed"),
      Importance_Pct = c(35, 25, 20, 5, 10, 5),
      stringsAsFactors = FALSE
    ),
    SegC = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Convenience", "Speed"),
      Importance_Pct = c(30, 30, 15, 8, 12, 5),
      stringsAsFactors = FALSE
    )
  )

  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3, rank_diff_threshold = 3)

  brand_class <- classes$Classification[classes$Driver == "Brand"]
  expect_equal(brand_class, "Segment-Specific")

  # The description should mention the best and worst segments
  brand_desc <- classes$Description[classes$Driver == "Brand"]
  expect_true(grepl("SegA", brand_desc))
})

test_that("classify_drivers identifies Mixed and Low Priority drivers", {
  seg_results <- list(
    SegA = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Speed", "Location"),
      Importance_Pct = c(35, 25, 20, 10, 6, 4),
      stringsAsFactors = FALSE
    ),
    SegB = data.frame(
      Driver = c("Price", "Quality", "Service", "Brand", "Speed", "Location"),
      Importance_Pct = c(30, 28, 22, 12, 5, 3),
      stringsAsFactors = FALSE
    )
  )

  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3, rank_diff_threshold = 3)

  # Location should be Low Priority (bottom half in both segments)
  location_class <- classes$Classification[classes$Driver == "Location"]
  expect_equal(location_class, "Low Priority")

  # All four classification types should be valid strings
  valid_types <- c("Universal", "Segment-Specific", "Mixed", "Low Priority")
  expect_true(all(classes$Classification %in% valid_types))
})

test_that("classify_drivers returns correct columns", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat)

  expect_true(is.data.frame(classes))
  expect_equal(sort(names(classes)), sort(c("Driver", "Classification", "Description")))
  expect_equal(nrow(classes), nrow(mat))
})


# ==============================================================================
# TESTS: generate_segment_insights()
# ==============================================================================

test_that("generate_segment_insights returns character vector of insights", {
  seg_results <- build_three_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3)

  insights <- generate_segment_insights(mat, classes)

  expect_true(is.character(insights))
  expect_true(length(insights) >= 2)  # At minimum, consistency summary + classification summary
})

test_that("generate_segment_insights includes classification summary counts", {
  seg_results <- build_three_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3)

  insights <- generate_segment_insights(mat, classes)

  # Should include a summary line with counts like "X universal drivers, ..."
  summary_insight <- insights[grepl("universal drivers", insights, ignore.case = TRUE)]
  expect_true(length(summary_insight) >= 1)
})

test_that("generate_segment_insights works with 2 segments", {
  seg_results <- build_two_segment_results()
  mat <- build_importance_comparison_matrix(seg_results)
  classes <- classify_drivers(mat, top_n = 3)

  insights <- generate_segment_insights(mat, classes)

  expect_true(is.character(insights))
  expect_true(length(insights) >= 1)

  # Should include consistency summary
  consistency_insight <- insights[grepl("consistent importance", insights, ignore.case = TRUE)]
  expect_true(length(consistency_insight) >= 1)
})


# ==============================================================================
# TESTS: Edge Cases
# ==============================================================================

test_that("Edge case: single driver across segments", {
  seg_results <- list(
    SegA = data.frame(
      Driver = "Price",
      Importance_Pct = 100,
      stringsAsFactors = FALSE
    ),
    SegB = data.frame(
      Driver = "Price",
      Importance_Pct = 100,
      stringsAsFactors = FALSE
    )
  )

  mat <- build_importance_comparison_matrix(seg_results)
  expect_equal(nrow(mat), 1)
  expect_equal(mat$Driver, "Price")

  classes <- classify_drivers(mat, top_n = 3)
  expect_equal(nrow(classes), 1)
  # Single driver ranked #1 in both segments should be Universal
  expect_equal(classes$Classification, "Universal")

  insights <- generate_segment_insights(mat, classes)
  expect_true(is.character(insights))
  expect_true(length(insights) >= 1)
})

test_that("build_importance_comparison_matrix refuses empty input", {
  expect_error(
    build_importance_comparison_matrix(list()),
    class = "turas_refusal"
  )
})

test_that("build_importance_comparison_matrix refuses unnamed list", {
  seg_results <- list(
    data.frame(Driver = "Price", Importance_Pct = 50, stringsAsFactors = FALSE),
    data.frame(Driver = "Price", Importance_Pct = 50, stringsAsFactors = FALSE)
  )

  expect_error(
    build_importance_comparison_matrix(seg_results),
    class = "turas_refusal"
  )
})
