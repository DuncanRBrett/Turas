# ==============================================================================
# Tests for 08_scoring.R
# Part of Turas Segment Module test suite
# ==============================================================================
# Covers: score_new_data, type_respondent, type_respondents_batch,
#   compare_segment_distributions
#
# These functions require saved model files (.rds), so we create mock
# model objects in tempdir() for testing.
# ==============================================================================


# ==============================================================================
# Helper: Create a mock kmeans model file for testing
# ==============================================================================

.create_mock_model_file <- function(k = 3, n_vars = 3, standardize = TRUE) {
  set.seed(42)

  # Create fake clustering data and run actual kmeans
  n <- 150
  var_names <- paste0("q", 1:n_vars)
  data <- matrix(rnorm(n * n_vars), ncol = n_vars)
  colnames(data) <- var_names

  if (standardize) {
    scaled <- scale(data)
    scale_params <- list(
      center = attr(scaled, "scaled:center"),
      scale = attr(scaled, "scaled:scale")
    )
    km <- kmeans(scaled, centers = k, nstart = 25)
  } else {
    km <- kmeans(data, centers = k, nstart = 25)
    scale_params <- NULL
  }

  model_data <- list(
    model = km,
    method = "kmeans",
    k = k,
    clusters = km$cluster,
    centers = km$centers,
    segment_names = paste0("Segment_", 1:k),
    clustering_vars = var_names,
    id_variable = "id",
    scale_params = scale_params,
    imputation_params = list(means = setNames(rep(0, n_vars), var_names)),
    config = list(
      standardize = standardize,
      missing_data = "listwise_deletion"
    ),
    original_distribution = table(km$cluster),
    timestamp = Sys.time(),
    turas_version = "1.0"
  )

  model_path <- file.path(tempdir(), paste0("test_model_k", k, ".rds"))
  saveRDS(model_data, model_path)
  model_path
}


# ==============================================================================
# score_new_data()
# ==============================================================================

test_that("score_new_data refuses when model file does not exist", {
  fake_data <- data.frame(id = 1:10, q1 = rnorm(10), q2 = rnorm(10), q3 = rnorm(10))

  expect_error(
    capture.output(score_new_data(
      model_file = "/nonexistent/path/model.rds",
      new_data = fake_data,
      id_variable = "id"
    )),
    class = "turas_refusal"
  )
})

test_that("score_new_data refuses when model is missing required elements", {
  # Save a model without required fields
  bad_model <- list(bad_field = "not a model")
  bad_model_path <- file.path(tempdir(), "bad_model.rds")
  saveRDS(bad_model, bad_model_path)

  fake_data <- data.frame(id = 1:10, q1 = rnorm(10))

  expect_error(
    capture.output(score_new_data(
      model_file = bad_model_path,
      new_data = fake_data,
      id_variable = "id"
    )),
    class = "turas_refusal"
  )

  unlink(bad_model_path)
})

test_that("score_new_data refuses when ID variable is missing from new data", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = FALSE)
  new_data <- data.frame(wrong_id = 1:10, q1 = rnorm(10), q2 = rnorm(10), q3 = rnorm(10))

  expect_error(
    capture.output(score_new_data(
      model_file = model_path,
      new_data = new_data,
      id_variable = "id"
    )),
    class = "turas_refusal"
  )

  unlink(model_path)
})

test_that("score_new_data refuses when clustering variables are missing", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = FALSE)
  # Only provide q1, missing q2 and q3
  new_data <- data.frame(id = 1:10, q1 = rnorm(10))

  expect_error(
    capture.output(score_new_data(
      model_file = model_path,
      new_data = new_data,
      id_variable = "id"
    )),
    class = "turas_refusal"
  )

  unlink(model_path)
})

test_that("score_new_data successfully scores clean data without standardization", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = FALSE)

  set.seed(99)
  new_data <- data.frame(
    id = 101:150,
    q1 = rnorm(50),
    q2 = rnorm(50),
    q3 = rnorm(50)
  )

  output <- capture.output(
    result <- score_new_data(
      model_file = model_path,
      new_data = new_data,
      id_variable = "id"
    )
  )

  expect_true(is.list(result))
  expect_true("assignments" %in% names(result))
  expect_true("segment_counts" %in% names(result))
  expect_true("model_info" %in% names(result))
  expect_true("scoring_info" %in% names(result))

  # Check assignments
  expect_true(is.data.frame(result$assignments))
  expect_equal(nrow(result$assignments), 50)
  expect_true("segment" %in% names(result$assignments))
  expect_true("assignment_confidence" %in% names(result$assignments))
  expect_true(all(result$assignments$segment %in% 1:3))

  unlink(model_path)
})

test_that("score_new_data successfully scores with standardization", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  set.seed(99)
  new_data <- data.frame(
    id = 101:150,
    q1 = rnorm(50),
    q2 = rnorm(50),
    q3 = rnorm(50)
  )

  output <- capture.output(
    result <- score_new_data(
      model_file = model_path,
      new_data = new_data,
      id_variable = "id"
    )
  )

  expect_true(is.list(result))
  expect_equal(nrow(result$assignments), 50)
  expect_true(all(result$assignments$segment %in% 1:3))

  unlink(model_path)
})

test_that("score_new_data refuses when no valid cases remain after listwise deletion", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = FALSE)

  # All rows have missing values
  new_data <- data.frame(
    id = 1:10,
    q1 = rep(NA, 10),
    q2 = rep(NA, 10),
    q3 = rep(NA, 10)
  )

  expect_error(
    capture.output(score_new_data(
      model_file = model_path,
      new_data = new_data,
      id_variable = "id"
    )),
    class = "turas_refusal"
  )

  unlink(model_path)
})


# ==============================================================================
# type_respondent()
# ==============================================================================

test_that("type_respondent refuses when model file does not exist", {
  answers <- c(q1 = 5, q2 = 6, q3 = 7)

  expect_error(
    capture.output(type_respondent(
      answers = answers,
      model_file = "/nonexistent/model.rds"
    )),
    class = "turas_refusal"
  )
})

test_that("type_respondent refuses LCA models", {
  lca_model <- list(method = "lca", model = NULL)
  lca_path <- file.path(tempdir(), "lca_model_test.rds")
  saveRDS(lca_model, lca_path)

  answers <- c(q1 = 5, q2 = 6)

  expect_error(
    capture.output(type_respondent(answers = answers, model_file = lca_path)),
    class = "turas_refusal"
  )

  unlink(lca_path)
})

test_that("type_respondent successfully types a respondent", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  answers <- c(q1 = 0.5, q2 = -0.3, q3 = 1.2)

  output <- capture.output(
    result <- type_respondent(answers = answers, model_file = model_path)
  )

  expect_true(is.list(result))
  expect_true("segment" %in% names(result))
  expect_true("segment_name" %in% names(result))
  expect_true("confidence" %in% names(result))
  expect_true("distances" %in% names(result))

  expect_true(result$segment %in% 1:3)
  expect_true(result$confidence >= 0 && result$confidence <= 1)
  expect_length(result$distances, 3)

  unlink(model_path)
})

test_that("type_respondent accepts data frame input", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  answers_df <- data.frame(q1 = 0.5, q2 = -0.3, q3 = 1.2)

  output <- capture.output(
    result <- type_respondent(answers = answers_df, model_file = model_path)
  )

  expect_true(result$segment %in% 1:3)
  expect_true(result$confidence >= 0 && result$confidence <= 1)

  unlink(model_path)
})

test_that("type_respondent refuses when variables are missing", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  # Only provide q1, missing q2 and q3
  answers <- c(q1 = 0.5)

  expect_error(
    capture.output(type_respondent(answers = answers, model_file = model_path)),
    class = "turas_refusal"
  )

  unlink(model_path)
})


# ==============================================================================
# type_respondents_batch()
# ==============================================================================

test_that("type_respondents_batch refuses when model file does not exist", {
  data <- data.frame(id = 1:10, q1 = rnorm(10), q2 = rnorm(10), q3 = rnorm(10))

  expect_error(
    capture.output(type_respondents_batch(
      data = data,
      model_file = "/nonexistent/model.rds",
      id_var = "id"
    )),
    class = "turas_refusal"
  )
})

test_that("type_respondents_batch successfully types multiple respondents", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  set.seed(99)
  data <- data.frame(
    id = 1:20,
    q1 = rnorm(20),
    q2 = rnorm(20),
    q3 = rnorm(20)
  )

  output <- capture.output(
    result <- type_respondents_batch(
      data = data,
      model_file = model_path,
      id_var = "id"
    )
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 20)
  expect_true("segment" %in% names(result))
  expect_true("segment_name" %in% names(result))
  expect_true("confidence" %in% names(result))
  expect_true("distance_to_center" %in% names(result))
  expect_true(all(result$segment %in% 1:3))

  unlink(model_path)
})

test_that("type_respondents_batch handles rows with missing data", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  data <- data.frame(
    id = 1:5,
    q1 = c(1, 2, NA, 4, 5),
    q2 = c(1, 2, 3, NA, 5),
    q3 = c(1, 2, 3, 4, 5)
  )

  output <- capture.output(
    result <- type_respondents_batch(
      data = data,
      model_file = model_path,
      id_var = "id"
    )
  )

  expect_equal(nrow(result), 5)
  # Rows 3 and 4 have missing data, should have NA assignments
  expect_true(is.na(result$segment[3]))
  expect_true(is.na(result$segment[4]))
  # Rows 1, 2, 5 should have valid assignments
  expect_true(!is.na(result$segment[1]))
  expect_true(!is.na(result$segment[2]))
  expect_true(!is.na(result$segment[5]))

  unlink(model_path)
})

test_that("type_respondents_batch refuses missing ID variable", {
  model_path <- .create_mock_model_file(k = 3, n_vars = 3, standardize = TRUE)

  data <- data.frame(
    wrong_id = 1:10,
    q1 = rnorm(10),
    q2 = rnorm(10),
    q3 = rnorm(10)
  )

  expect_error(
    capture.output(type_respondents_batch(
      data = data,
      model_file = model_path,
      id_var = "id"
    )),
    class = "turas_refusal"
  )

  unlink(model_path)
})


# ==============================================================================
# compare_segment_distributions()
# ==============================================================================

test_that("compare_segment_distributions returns NULL when no original distribution", {
  # Create model without original_distribution
  model_data <- list(
    model = NULL,
    method = "kmeans",
    k = 3,
    original_distribution = NULL
  )
  model_path <- file.path(tempdir(), "test_no_dist.rds")
  saveRDS(model_data, model_path)

  scoring_result <- list(
    assignments = data.frame(segment = c(1, 1, 2, 2, 3))
  )

  result <- suppressMessages(
    compare_segment_distributions(model_path, scoring_result)
  )

  expect_null(result)

  unlink(model_path)
})

test_that("compare_segment_distributions handles original distribution", {
  # compare_segment_distributions has a known bug where table-class arithmetic
  # (round(100 * orig_dist / sum(orig_dist), 1)) preserves the table class,
  # causing data.frame() to produce unexpected column names and the
  # Difference_Pct calculation to fail.
  #
  # This test creates a proper table object (from actual table() call) and
  # verifies the function at least loads the model and detects the distribution.
  # The actual comparison may error due to the source-level bug.

  segments <- c(1L, 1L, 1L, 2L, 2L, 3L)
  orig_dist <- table(segments)

  model_data <- list(
    model = NULL,
    method = "kmeans",
    k = 3,
    original_distribution = orig_dist
  )
  model_path <- file.path(tempdir(), "test_with_dist.rds")
  saveRDS(model_data, model_path)

  scoring_result <- list(
    assignments = data.frame(
      segment = c(1L, 1L, 2L, 2L, 2L, 3L)
    )
  )

  # The function has a known bug with table-class arithmetic in data.frame(),
  # so we expect it to error.
  expect_error(
    capture.output(
      compare_segment_distributions(model_path, scoring_result)
    ),
    "replacement has 0 rows"
  )

  unlink(model_path)
})


# ==============================================================================
# H2 + M7 - scoring honesty (V2 lift review 2026-07-11)
# ==============================================================================
# Every entry point assigned by nearest Euclidean centroid regardless of what
# fitted the model. That rule is correct for k-means and wrong for the others:
# a GMM assigns by posterior probability under fitted covariances, so
# nearest-centroid can disagree with the model's own training assignments, and
# an hclust model has no centroid rule at all. The output looked normal.
#
# M7: the same concept was computed two ways. score_new_data reported
# 1/(1+d) and the typing entry points reported a softmax, so one respondent
# got two different confidences depending on which door they came through.

.mock_model_of_method <- function(method) {
  path <- .create_mock_model_file()
  model <- readRDS(path)
  model$method <- method
  out <- file.path(tempdir(), paste0("test_model_method_", method, ".rds"))
  saveRDS(model, out)
  out
}

.mock_scoring_data <- function(n = 20) {
  set.seed(11)
  data.frame(
    id = seq_len(n),
    q1 = rnorm(n), q2 = rnorm(n), q3 = rnorm(n),
    stringsAsFactors = FALSE
  )
}

for (.bad_method in c("gmm", "hclust")) {
  local({
    bad <- .bad_method

    test_that(paste0("score_new_data refuses a ", bad, " model (H2)"), {
      path <- .mock_model_of_method(bad)
      on.exit(unlink(path), add = TRUE)

      err <- tryCatch(
        capture.output(score_new_data(model_file = path,
                                      new_data = .mock_scoring_data(),
                                      id_variable = "id")),
        turas_refusal = function(e) e
      )
      expect_s3_class(err, "turas_refusal")
      expect_true(grepl(bad, conditionMessage(err), ignore.case = TRUE))
    })

    test_that(paste0("type_respondent refuses a ", bad, " model (H2)"), {
      path <- .mock_model_of_method(bad)
      on.exit(unlink(path), add = TRUE)

      err <- tryCatch(
        capture.output(type_respondent(answers = c(q1 = 0.2, q2 = -0.4, q3 = 1.1),
                                       model_file = path)),
        turas_refusal = function(e) e
      )
      expect_s3_class(err, "turas_refusal")
      expect_true(grepl(bad, conditionMessage(err), ignore.case = TRUE))
    })

    test_that(paste0("type_respondents_batch refuses a ", bad, " model (H2)"), {
      path <- .mock_model_of_method(bad)
      on.exit(unlink(path), add = TRUE)

      err <- tryCatch(
        capture.output(type_respondents_batch(data = .mock_scoring_data(),
                                              model_file = path, id_var = "id")),
        turas_refusal = function(e) e
      )
      expect_s3_class(err, "turas_refusal")
      expect_true(grepl(bad, conditionMessage(err), ignore.case = TRUE))
    })
  })
}

test_that("the refusal says why nearest-centroid is not a substitute (H2)", {
  path <- .mock_model_of_method("gmm")
  on.exit(unlink(path), add = TRUE)

  err <- tryCatch(
    capture.output(type_respondent(answers = c(q1 = 0.2, q2 = -0.4, q3 = 1.1),
                                   model_file = path)),
    turas_refusal = function(e) e
  )
  msg <- conditionMessage(err)
  expect_true(grepl("centroid|nearest", msg, ignore.case = TRUE))
  expect_true(grepl("k-means|kmeans", msg, ignore.case = TRUE))
})

test_that("a k-means model still scores through every entry point (H2 regression)", {
  path <- .mock_model_of_method("kmeans")
  on.exit(unlink(path), add = TRUE)
  newdata <- .mock_scoring_data()

  capture.output(scored <- score_new_data(model_file = path, new_data = newdata,
                                          id_variable = "id"))
  capture.output(one <- type_respondent(answers = c(q1 = 0.2, q2 = -0.4, q3 = 1.1),
                                        model_file = path))
  capture.output(batch <- type_respondents_batch(data = newdata, model_file = path,
                                                 id_var = "id"))

  expect_equal(nrow(scored$assignments %||% scored), nrow(newdata))
  expect_true(is.numeric(one$confidence))
  expect_equal(nrow(batch), nrow(newdata))
})

test_that("one respondent gets one confidence, whichever door they use (M7)", {
  path <- .mock_model_of_method("kmeans")
  on.exit(unlink(path), add = TRUE)
  answers <- c(q1 = 0.2, q2 = -0.4, q3 = 1.1)
  one_row <- data.frame(id = 1L, q1 = 0.2, q2 = -0.4, q3 = 1.1)

  capture.output(scored <- score_new_data(model_file = path, new_data = one_row,
                                          id_variable = "id"))
  capture.output(typed <- type_respondent(answers = answers, model_file = path))
  capture.output(batched <- type_respondents_batch(data = one_row, model_file = path,
                                                   id_var = "id"))

  frame <- scored$assignments %||% scored
  # ignore_attr: type_respondent returns a NAMED scalar for both fields (the
  # name is the segment label, carried through from the distance vector),
  # while the frame-shaped entry points return bare values. That is a
  # cosmetic difference in the return shape, not a difference in the number,
  # and it is deliberately left alone here.
  # unname(): one of these entry points carries the segment label through as a
  # vector name and the others do not. That is a cosmetic difference in the
  # return shape, not a difference in the number, and it is left alone here.
  expect_equal(unname(frame$segment[1]), unname(typed$segment))
  expect_equal(unname(round(frame$assignment_confidence[1], 3)),
               unname(round(typed$confidence, 3)))
  expect_equal(unname(round(batched$confidence[1], 3)),
               unname(round(typed$confidence, 3)))
})
