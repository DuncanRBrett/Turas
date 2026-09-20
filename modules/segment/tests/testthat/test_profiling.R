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


# ==============================================================================
# M3 - a nominal variable was tested as if it were ordered
# ==============================================================================
# test_segment_differences() sent anything with fewer than 10 distinct values
# to kruskal.test. Its own comment promised "Chi-square or Kruskal-Wallis",
# but chi-square was never called. Kruskal-Wallis ranks its input, so region
# coded 1 to 9 was tested as though 9 were more than 1, and a genuinely
# nominal variable got a p-value that assumed an order nobody claimed.

.m3_frame <- function(n = 180, seed = 8) {
  set.seed(seed)
  clusters <- rep(1:3, length.out = n)
  data.frame(
    region_chr = ifelse(clusters == 1, "North",
                 ifelse(clusters == 2, "South", "East")),
    region_fct = factor(ifelse(clusters == 1, "North",
                        ifelse(clusters == 2, "South", "East"))),
    grade_ord  = factor(pmin(5, pmax(1, round(clusters + rnorm(n, 0, 0.4)))),
                        ordered = TRUE),
    score_few  = pmin(5, pmax(1, round(clusters + rnorm(n, 0, 0.4)))),
    score_cont = clusters + rnorm(n),
    clusters   = clusters,
    stringsAsFactors = FALSE
  )
}

test_that("a character variable is tested with chi-square, not Kruskal-Wallis (M3)", {
  d <- .m3_frame()
  capture.output(res <- test_segment_differences(d, d$clusters, "region_chr"))

  expect_equal(nrow(res), 1)
  expect_equal(res$Test[1], "Chi-square")
})

test_that("an unordered factor is tested with chi-square (M3)", {
  d <- .m3_frame()
  capture.output(res <- test_segment_differences(d, d$clusters, "region_fct"))

  expect_equal(res$Test[1], "Chi-square")
})

test_that("a numeric variable with few values keeps Kruskal-Wallis (M3)", {
  # The fix must not swallow the case Kruskal-Wallis is right for: a 1-5
  # rating has an order, and ranking it is the point.
  d <- .m3_frame()
  capture.output(res <- test_segment_differences(d, d$clusters, "score_few"))

  expect_equal(res$Test[1], "Kruskal-Wallis")
})

test_that("an ordered factor keeps Kruskal-Wallis (M3)", {
  d <- .m3_frame()
  capture.output(res <- test_segment_differences(d, d$clusters, "grade_ord"))

  expect_equal(res$Test[1], "Kruskal-Wallis")
})

test_that("a continuous variable still gets ANOVA (M3 regression)", {
  d <- .m3_frame()
  capture.output(res <- test_segment_differences(d, d$clusters, "score_cont"))

  expect_equal(res$Test[1], "ANOVA")
})

test_that("the chi-square effect size is Cramer's V, bounded and ordered (M3)", {
  d <- .m3_frame()
  set.seed(3)
  d$region_noise <- sample(c("North", "South", "East"), nrow(d), replace = TRUE)

  capture.output(res <- test_segment_differences(d, d$clusters,
                                                 c("region_chr", "region_noise")))

  v <- setNames(res$Effect_Size, res$Variable)
  expect_true(all(v >= 0 & v <= 1))
  # region_chr is the segment, recoded. Noise is not.
  expect_true(v[["region_chr"]] > v[["region_noise"]])
})

test_that("a variable with too many categories is reported, not silently dropped (M3)", {
  d <- .m3_frame()
  d$open_end <- paste0("answer_", seq_len(nrow(d)))

  out <- capture.output(res <- test_segment_differences(d, d$clusters, "open_end"))

  expect_equal(nrow(res), 0)
  expect_true(grepl("open_end", paste(out, collapse = " ")))
})
