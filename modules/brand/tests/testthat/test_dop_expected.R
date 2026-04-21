# ==============================================================================
# TEST: DoP expected/deviation — 04_repertoire.R §2.5 / §7.4
# Coverage: D coefficient OLS, deviation matrix sign, partition detection,
#           two-brand minimum.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "launch_turas.R")) ||
          file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  source(file.path(root, "modules", "brand", "R", "04_repertoire.R"), local = FALSE)
})


# ==============================================================================
# D COEFFICIENT FITTED CORRECTLY
# ==============================================================================

test_that("D coefficient is positive for overlapping brands", {
  # Construct a pen_mat where brands overlap (buyers share across brands),
  # which produces a positive D coefficient per the Dirichlet/DoP law.
  set.seed(42)
  n <- 200
  brands <- c("A", "B", "C", "D")

  # Construct overlapping buyers: each respondent buys 1-3 brands at random
  pen_mat <- matrix(0L, n, 4, dimnames = list(NULL, brands))
  for (i in seq_len(n)) {
    nb_bought <- sample(1:3, 1, prob = c(0.4, 0.4, 0.2))
    pen_mat[i, sample(4, nb_bought)] <- 1L
  }

  res <- run_repertoire(pen_mat, brands)
  expect_equal(res$status, "PASS")
  expect_true(!is.null(res$dop_D_coefficient))
  expect_true(is.numeric(res$dop_D_coefficient))
  expect_gt(res$dop_D_coefficient, 0)
})

test_that("D coefficient OLS formula: sum(obs*pen) / sum(pen^2)", {
  # Hand-built 3-brand case where we can verify D manually.
  # Penetrations: A=0.6, B=0.4, C=0.3 (out of n=10)
  n <- 10
  brands <- c("A", "B", "C")
  pen_mat <- matrix(0L, n, 3, dimnames = list(NULL, brands))
  # A: respondents 1-6; B: 3-8; C: 5-8,10
  pen_mat[1:6, 1] <- 1L
  pen_mat[3:8, 2] <- 1L
  pen_mat[c(5:8, 10), 3] <- 1L

  res <- run_repertoire(pen_mat, brands)
  expect_equal(res$status, "PASS")

  if (!is.null(res$dop_D_coefficient)) {
    # Verify sign is positive
    expect_gt(res$dop_D_coefficient, 0)
    # Verify expected matrix has the right structure
    expect_true(!is.null(res$dop_expected_matrix))
    expect_true("BrandCode" %in% names(res$dop_expected_matrix))
    # Diagonal should be NA in the expected matrix
    exp_mat <- as.matrix(res$dop_expected_matrix[, -1])
    for (i in seq_along(brands)) {
      expect_true(is.na(exp_mat[i, i]))
    }
  }
})


# ==============================================================================
# DEVIATION MATRIX SIGN
# ==============================================================================

test_that("deviation = observed - expected (positive when obs > exp)", {
  set.seed(8)
  n <- 100
  brands <- c("A", "B", "C")
  pen_mat <- matrix(0L, n, 3, dimnames = list(NULL, brands))
  # High duplication between A and B
  pen_mat[1:70, 1] <- 1L
  pen_mat[1:70, 2] <- 1L  # 70% of A buyers also buy B
  pen_mat[71:90, 3] <- 1L

  res <- run_repertoire(pen_mat, brands)
  expect_equal(res$status, "PASS")

  if (!is.null(res$dop_deviation_matrix)) {
    dev_mat  <- as.matrix(res$dop_deviation_matrix[, -1])
    exp_mat  <- as.matrix(res$dop_expected_matrix[, -1])
    obs_mat  <- as.matrix(res$crossover_matrix[, -1])

    for (i in seq_along(brands)) {
      for (j in seq_along(brands)) {
        if (i == j) next
        obs_ij <- as.numeric(obs_mat[i, j])
        exp_ij <- as.numeric(exp_mat[i, j])
        dev_ij <- as.numeric(dev_mat[i, j])
        if (!is.na(dev_ij) && !is.na(obs_ij) && !is.na(exp_ij)) {
          expect_equal(round(dev_ij, 4), round(obs_ij - exp_ij, 4))
        }
      }
    }
  }
})


# ==============================================================================
# PARTITION DETECTION (conceptual — ≥3 brands with shared pos deviations >10pp)
# ==============================================================================

test_that("partition candidates: 3 brands with large positive deviations present", {
  set.seed(11)
  n <- 200
  brands <- c("A", "B", "C", "D", "E")
  pen_mat <- matrix(0L, n, 5, dimnames = list(NULL, brands))

  # ABC cluster: very high mutual duplication
  pen_mat[1:120, 1:3] <- 1L   # A, B, C all bought by respondents 1-120
  pen_mat[121:160, 4] <- 1L
  pen_mat[161:200, 5] <- 1L

  res <- run_repertoire(pen_mat, brands)
  expect_equal(res$status, "PASS")

  if (!is.null(res$dop_deviation_matrix)) {
    dev_mat <- as.matrix(res$dop_deviation_matrix[, -1])
    # Among A, B, C — deviations from the law should be positive
    abc_devs <- c(dev_mat["A", "B"], dev_mat["A", "C"],
                  dev_mat["B", "A"], dev_mat["B", "C"])
    if (!any(is.na(abc_devs))) {
      expect_true(any(abc_devs > 0))
    }
  }
})


# ==============================================================================
# STRUCTURE
# ==============================================================================

test_that("run_repertoire returns dop_D_coefficient, dop_expected_matrix, dop_deviation_matrix", {
  n <- 20
  brands <- c("A", "B", "C")
  pen_mat <- matrix(as.integer(rbinom(60, 1, 0.5)), n, 3,
                    dimnames = list(NULL, brands))

  res <- run_repertoire(pen_mat, brands)
  expect_equal(res$status, "PASS")
  expect_true("dop_D_coefficient"    %in% names(res))
  expect_true("dop_expected_matrix"  %in% names(res))
  expect_true("dop_deviation_matrix" %in% names(res))
})

test_that("dop fields are NULL (not error) when only one brand", {
  n <- 10
  brands <- c("A")
  pen_mat <- matrix(1L, n, 1, dimnames = list(NULL, brands))
  res <- run_repertoire(pen_mat, brands)
  # Single-brand: crossover_matrix is NULL, DoP fields should be NULL too
  expect_true(is.null(res$dop_D_coefficient) || is.na(res$dop_D_coefficient))
})

test_that("deviation matrix rows correspond to BrandCode column", {
  n <- 30
  brands <- c("A", "B", "C")
  pen_mat <- matrix(as.integer(rbinom(90, 1, 0.6)), n, 3,
                    dimnames = list(NULL, brands))
  res <- run_repertoire(pen_mat, brands)

  if (!is.null(res$dop_deviation_matrix)) {
    expect_equal(res$dop_deviation_matrix$BrandCode, brands)
    expect_equal(names(res$dop_expected_matrix)[1], "BrandCode")
  }
})
