# ==============================================================================
# SEGMENT MODULE TESTS - PROFILING
# ==============================================================================

test_that("create_segment_profiles calculates correct means", {
  data <- data.frame(
    q1 = c(1, 2, 3, 7, 8, 9),
    q2 = c(5, 5, 5, 5, 5, 5),
    stringsAsFactors = FALSE
  )
  clusters <- c(1, 1, 1, 2, 2, 2)

  result <- create_segment_profiles(data, clusters, c("q1", "q2"))

  expect_equal(nrow(result), 2)
  expect_equal(result$Overall[1], mean(data$q1))  # q1 overall
  expect_equal(result$Segment_1[1], 2)              # q1 seg 1 mean
  expect_equal(result$Segment_2[1], 8)              # q1 seg 2 mean
  expect_equal(result$Segment_1[2], 5)              # q2 seg 1 mean (identical)
  expect_equal(result$Segment_2[2], 5)              # q2 seg 2 mean (identical)
})

test_that("create_segment_profiles handles non-numeric variables", {
  data <- data.frame(
    q1 = c(1, 2, 3, 4),
    category = c("A", "B", "A", "B"),
    stringsAsFactors = FALSE
  )
  clusters <- c(1, 1, 2, 2)

  result <- create_segment_profiles(data, clusters, c("q1", "category"))
  expect_equal(nrow(result), 2)
  expect_true(is.na(result$Overall[2]))  # category should be NA
})

test_that("calculate_segment_differences returns valid ANOVA", {
  set.seed(42)
  data <- data.frame(
    q1 = c(rnorm(50, mean = 3), rnorm(50, mean = 7)),
    q2 = rnorm(100, mean = 5),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 50), rep(2, 50))

  result <- calculate_segment_differences(data, clusters, c("q1", "q2"))
  expect_equal(nrow(result), 2)
  expect_true(result$p_value[1] < 0.05)  # q1 should be significant
})

test_that("create_full_segment_profile returns complete structure", {
  test_data <- generate_segment_test_data(n = 100, k_true = 2, n_vars = 4, seed = 42)
  data <- test_data$data
  clusters <- c(rep(1, 50), rep(2, nrow(data) - 50))

  result <- create_full_segment_profile(
    data = data,
    clusters = clusters,
    clustering_vars = test_data$clustering_vars
  )

  expect_true(is.list(result))
  expect_true(!is.null(result$clustering_profile))
  expect_true(!is.null(result$segment_sizes))
  expect_equal(result$k, 2)
  expect_equal(sum(result$segment_sizes$Count), nrow(data))
})

test_that("generate_segment_names returns correct count", {
  names <- generate_segment_names(4, method = "simple")
  expect_equal(length(names), 4)
  expect_equal(names[1], "Segment 1")
  expect_equal(names[4], "Segment 4")
})

test_that("generate_segment_names handles descriptive style", {
  set.seed(42)
  data <- data.frame(
    q1 = c(rnorm(50, 8), rnorm(50, 3)),
    q2 = c(rnorm(50, 7), rnorm(50, 4)),
    stringsAsFactors = FALSE
  )
  clusters <- c(rep(1, 50), rep(2, 50))

  names <- generate_segment_names(2, method = "descriptive",
    data = data, clusters = clusters,
    clustering_vars = c("q1", "q2"), scale_max = 10)
  expect_equal(length(names), 2)
  expect_true(all(nchar(names) > 0))
})

test_that("profile_demographics handles categorical variables", {
  data <- data.frame(
    gender = sample(c("M", "F"), 100, replace = TRUE),
    age = sample(c("Young", "Middle", "Senior"), 100, replace = TRUE),
    stringsAsFactors = FALSE
  )
  clusters <- sample(1:3, 100, replace = TRUE)

  result <- profile_demographics(data, clusters,
    demo_vars = c("gender", "age"),
    segment_names = paste0("Seg", 1:3))

  expect_true(is.list(result))
  expect_true(length(result$categorical_profiles) >= 1)
  expect_true(!is.null(result$chi_sq_tests))
})
