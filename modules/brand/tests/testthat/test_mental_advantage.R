# ==============================================================================
# BRAND MODULE TESTS - MENTAL ADVANTAGE (ROMANIUK)
# ==============================================================================
# Strategy:
#   - Tiny textbook case (2x2, n=100) with hand-computable expected values
#     verifies the core formula end-to-end.
#   - Quantilope worked example (5x5, n=1000) reproduces Brand 1 / Comfortable
#     +9.7pp (rounds to +10pp) — the public reference number.
#   - Algebraic invariants: sum of (actual - expected) is always 0.
#   - Decision categorisation, significance flagging, edge cases.
# ==============================================================================

# --- Setup ---
.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()
source(file.path(TURAS_ROOT, "modules", "brand", "R", "02b_mental_advantage.R"))


# --- Helper: build a brand-keyed linkage tensor from a count matrix --------
# Keeps the tests focused on the formula, not on tensor wiring. The function
# under test sums binary 0/1 entries per cell — placing 1's in the first k
# rows per (brand, stimulus) column produces the desired count.
.ma_tensor_from_counts <- function(count_mat, n_resp) {
  if (any(count_mat > n_resp))
    stop(".ma_tensor_from_counts: count exceeds n_resp; cannot construct binary cell")
  brand_codes <- colnames(count_mat)
  stim_codes  <- rownames(count_mat)
  tensor <- list()
  for (b in brand_codes) {
    bm <- matrix(0L, nrow = n_resp, ncol = length(stim_codes),
                 dimnames = list(NULL, stim_codes))
    for (s in stim_codes) {
      k <- as.integer(count_mat[s, b])
      if (k > 0) bm[seq_len(k), s] <- 1L
    }
    tensor[[b]] <- bm
  }
  tensor
}


# ==============================================================================
# 1. TEXTBOOK CASE (2x2)
# ==============================================================================

test_that("MA formula matches hand-computed values on a 2x2 textbook case", {
  # 2 brands x 2 stimuli, n=100
  # A/S1 = 30, A/S2 = 20  -> col_total[A] = 50
  # B/S1 = 10, B/S2 = 40  -> col_total[B] = 50
  # row totals: S1=40, S2=60. Grand=100.
  # expected[S1,A] = 40*50/100 = 20 -> ma = (30-20)/100*100 = +10pp -> defend
  # expected[S2,A] = 60*50/100 = 30 -> ma = (20-30)/100*100 = -10pp -> build
  count_mat <- matrix(c(30, 20, 10, 40), nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = 100)
  out <- calculate_mental_advantage(tensor, codes = c("S1","S2"),
                                     n_respondents = 100, threshold_pp = 5)

  expect_equal(out$status, "PASS")
  expect_equal(unname(out$grand_total), 100)
  expect_equal(unname(out$expected["S1","A"]), 20)
  expect_equal(unname(out$expected["S2","A"]), 30)
  expect_equal(unname(out$advantage["S1","A"]),  10)
  expect_equal(unname(out$advantage["S2","A"]), -10)
  expect_equal(unname(out$advantage["S1","B"]), -10)
  expect_equal(unname(out$advantage["S2","B"]),  10)
  expect_equal(unname(out$decision["S1","A"]), "defend")
  expect_equal(unname(out$decision["S2","A"]), "build")
})


test_that("MA standardised residual flags significant cells in 2x2 textbook case", {
  # Same 2x2 setup as above. z = (actual-expected)/sqrt(expected).
  # |z| at S1/A = 10/sqrt(20) = 2.236 > 1.96 -> significant
  # |z| at S2/A = 10/sqrt(30) = 1.826 < 1.96 -> NOT significant
  count_mat <- matrix(c(30, 20, 10, 40), nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = 100)
  out <- calculate_mental_advantage(tensor, codes = c("S1","S2"),
                                     n_respondents = 100)
  expect_true(out$is_significant["S1","A"])
  expect_true(out$is_significant["S1","B"])
  expect_false(out$is_significant["S2","A"])
  expect_false(out$is_significant["S2","B"])
  expect_equal(unname(out$std_residual["S1","A"]), 10/sqrt(20), tolerance = 1e-6)
})


# ==============================================================================
# 2. QUANTILOPE WORKED EXAMPLE
# ==============================================================================

test_that("MA reproduces Quantilope worked example: Brand 1 / Comfortable = +9.7pp", {
  # Source: Quantilope, "Brand Health Tracking Series: Mental Advantage Analysis".
  #   actual[Comfortable, Brand 1]      = 446
  #   row_total[Comfortable]            = 1454
  #   col_total[Brand 1]                = 2198
  #   grand_total                       = 9147
  #   n                                 = 1000
  #   expected = 1454 * 2198 / 9147     = 349.39
  #   MA       = (446 - 349.39)/1000*100 = 9.66 -> "10pp" rounded
  brands <- c("Brand 1","Brand 2","Brand 3","Brand 4","Brand 5")
  stims  <- c("Comfortable","Lightweight","Stylish","CrossFunctional","EasyClean")
  counts <- matrix(0L, nrow = 5, ncol = 5,
                   dimnames = list(stims, brands))
  # Brand 1 column: Comfortable=446, others 438 each -> col_total = 2198
  counts[, "Brand 1"] <- c(446, 438, 438, 438, 438)
  # Comfortable row: Brand 1=446, others 252 each -> row_total = 1454
  counts["Comfortable", c("Brand 2","Brand 3","Brand 4","Brand 5")] <- 252
  # Fill remaining 4x4 sub-block to hit grand_total = 9147.
  # Remaining sum needed: 9147 - 2198 - (252*4) = 5941. Across 16 cells,
  # use 371 base with a few +1 adjustments to land exactly on 5941 (371*16=5936).
  filler <- matrix(371L, nrow = 4, ncol = 4)
  filler[1, 1] <- 372L; filler[2, 2] <- 372L
  filler[3, 3] <- 372L; filler[4, 4] <- 373L  # +5 -> 5941
  counts[c("Lightweight","Stylish","CrossFunctional","EasyClean"),
         c("Brand 2","Brand 3","Brand 4","Brand 5")] <- filler

  expect_equal(sum(counts), 9147)
  expect_equal(sum(counts["Comfortable", ]), 1454)
  expect_equal(sum(counts[, "Brand 1"]), 2198)
  expect_equal(unname(counts["Comfortable","Brand 1"]), 446)

  tensor <- .ma_tensor_from_counts(counts, n_resp = 1000)
  out <- calculate_mental_advantage(tensor, codes = stims, n_respondents = 1000)

  expect_equal(unname(out$expected["Comfortable","Brand 1"]), 1454 * 2198 / 9147,
               tolerance = 1e-6)
  expect_equal(unname(out$advantage["Comfortable","Brand 1"]), 9.66, tolerance = 0.05)
  expect_equal(unname(out$decision["Comfortable","Brand 1"]), "defend")
})


# ==============================================================================
# 3. ALGEBRAIC INVARIANTS
# ==============================================================================

test_that("MA: sum of (actual - expected) is zero across whole matrix", {
  # Chi-square contingency property: row and column sums of expected match
  # those of actual, so the residual sum is exactly 0.
  set.seed(42)
  n_resp <- 200
  brands <- paste0("B", 1:4)
  stims  <- paste0("S", 1:6)
  count_mat <- matrix(sample.int(80, length(brands) * length(stims), replace = TRUE),
                      nrow = length(stims), ncol = length(brands),
                      dimnames = list(stims, brands))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = max(n_resp, max(count_mat)))
  out <- calculate_mental_advantage(tensor, codes = stims,
                                     n_respondents = max(n_resp, max(count_mat)))
  expect_equal(sum(out$actual - out$expected), 0, tolerance = 1e-9)
  expect_equal(sum(out$advantage), 0, tolerance = 1e-9)
})


test_that("MA: row and column marginals of expected equal those of actual", {
  count_mat <- matrix(c(30, 20, 10, 40), nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = 100)
  out <- calculate_mental_advantage(tensor, codes = c("S1","S2"), n_respondents = 100)
  expect_equal(rowSums(out$expected), rowSums(out$actual), tolerance = 1e-9)
  expect_equal(colSums(out$expected), colSums(out$actual), tolerance = 1e-9)
})


# ==============================================================================
# 4. DECISION CATEGORISATION
# ==============================================================================

test_that("MA decisions follow Defend / Build / Maintain rules at the threshold", {
  # Construct a matrix where MA scores hit each side of the +/- 5pp boundary.
  # Threshold = 5pp default. Verify edge values map correctly.
  scores <- c(7, -7, 2, -2, 5, -5, 0, NA_real_)
  decisions <- .ma_classify_decision(scores, threshold_pp = 5)
  expect_equal(decisions, c("defend","build","maintain","maintain",
                             "defend","build","maintain","na"))
})


# ==============================================================================
# 5. STIMULUS PENETRATION (X-AXIS OF QUADRANT)
# ==============================================================================

test_that("MA stimulus_penetration counts a respondent once even with multiple brand links", {
  # 3 respondents. R1 links A&B to S1; R2 links B to S1; R3 links nobody.
  # Penetration[S1] = 2/3 = 66.7% (any brand reach).
  tensor <- list(
    A = matrix(c(1,0,0), nrow = 3, ncol = 1, dimnames = list(NULL,"S1")),
    B = matrix(c(1,1,0), nrow = 3, ncol = 1, dimnames = list(NULL,"S1"))
  )
  out <- calculate_mental_advantage(tensor, codes = "S1", n_respondents = 3)
  expect_equal(unname(out$stim_penetration["S1"]), round(2/3 * 100, 1))
})


# ==============================================================================
# 6. EDGE CASES
# ==============================================================================

test_that("MA: zero linkage produces zero advantage and 'maintain' everywhere", {
  count_mat <- matrix(0L, nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = 50)
  out <- calculate_mental_advantage(tensor, codes = c("S1","S2"), n_respondents = 50)
  expect_equal(out$grand_total, 0)
  expect_true(all(out$advantage == 0))
  expect_true(all(out$decision == "maintain"))
})


test_that("MA: single brand always has zero advantage (only player gets all the share)", {
  # With one brand, expected = actual at every cell because col_total = grand_total.
  tensor <- list(A = matrix(c(1,0,1,1,0,1), nrow = 3, ncol = 2,
                              dimnames = list(NULL, c("S1","S2"))))
  out <- calculate_mental_advantage(tensor, codes = c("S1","S2"), n_respondents = 3)
  expect_true(all(out$advantage == 0))
})


test_that("MA: weighted call gives different counts but same algebraic invariant", {
  count_mat <- matrix(c(30, 20, 10, 40), nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- .ma_tensor_from_counts(count_mat, n_resp = 100)
  weights <- rep(2, 100)
  out_w <- calculate_mental_advantage(tensor, codes = c("S1","S2"),
                                       weights = weights, n_respondents = 200)
  # Every cell should double; MA percentages stay the same as unweighted.
  out_uw <- calculate_mental_advantage(tensor, codes = c("S1","S2"), n_respondents = 100)
  expect_equal(unname(out_w$actual["S1","A"]), 60)
  expect_equal(unname(out_w$advantage["S1","A"]),
               unname(out_uw$advantage["S1","A"]), tolerance = 1e-9)
})


test_that("MA throws on programming errors", {
  expect_error(calculate_mental_advantage(NULL, codes = "S1"))
  expect_error(calculate_mental_advantage(list(), codes = "S1"))
  expect_error(calculate_mental_advantage(list(A = matrix(0, 1, 1, dimnames = list(NULL,"S1"))),
                                           codes = character(0)))
  expect_error(calculate_mental_advantage(list(matrix(0, 1, 1, dimnames = list(NULL,"S1"))),
                                           codes = "S1"))  # unnamed list
  expect_error(calculate_mental_advantage(list(A = matrix(0, 1, 1, dimnames = list(NULL,"S1"))),
                                           codes = "S1", threshold_pp = -1))
})
