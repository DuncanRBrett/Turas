# ==============================================================================
# MAXDIFF TESTS - A8: RECOVERY AND COUNTS MATH (review S5)
# ==============================================================================
# The suite was green while never checking that the estimators recover a
# known truth, or that the counts arithmetic matches hand computation.

# Simulate MaxDiff choices from known true utilities (logit choice rule).
.sim_maxdiff_long <- function(true_utils, n_resp = 80, n_tasks = 8,
                              items_per_task = 4, seed = 11) {
  set.seed(seed)
  item_ids <- names(true_utils)
  rows <- list()
  for (r in seq_len(n_resp)) {
    for (t in seq_len(n_tasks)) {
      shown <- sample(item_ids, items_per_task)
      u <- true_utils[shown]
      p_best <- exp(u) / sum(exp(u))
      best <- sample(shown, 1, prob = p_best)
      remaining <- setdiff(shown, best)
      u_w <- true_utils[remaining]
      p_worst <- exp(-u_w) / sum(exp(-u_w))
      worst <- sample(remaining, 1, prob = p_worst)
      for (pos in seq_along(shown)) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = paste0("R", r), version = 1L, task = t,
          item_id = shown[pos], position = pos,
          is_best = as.integer(shown[pos] == best),
          is_worst = as.integer(shown[pos] == worst),
          weight = 1, stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  out$obs_id <- seq_len(nrow(out))
  out
}

.recovery_items <- function(item_ids) {
  data.frame(Item_ID = item_ids, Item_Label = item_ids,
             Item_Group = "G", Display_Order = seq_along(item_ids),
             Include = 1L, Anchor_Item = 0L, stringsAsFactors = FALSE)
}

TRUE_UTILS <- c(A = 1.6, B = 0.9, C = 0.3, D = -0.2, E = -0.9, F = -1.7)

test_that("recovery: aggregate logit rank-recovers known true utilities", {
  skip_if(!requireNamespace("survival", quietly = TRUE))

  long <- .sim_maxdiff_long(TRUE_UTILS)
  res <- fit_aggregate_logit(long, .recovery_items(names(TRUE_UTILS)),
                             weighted = FALSE, anchor_item = NULL,
                             verbose = FALSE)

  est <- res$utilities$Logit_Utility[match(names(TRUE_UTILS),
                                           res$utilities$Item_ID)]
  rho <- cor(est, TRUE_UTILS, method = "spearman")
  expect_gt(rho, 0.9)
  # And the extreme items land where they should.
  expect_equal(res$utilities$Item_ID[which.max(res$utilities$Logit_Utility)], "A")
})

test_that("recovery: the EB fallback rank-recovers known true utilities", {
  long <- .sim_maxdiff_long(TRUE_UTILS, seed = 12)
  res <- fit_approximate_hb(long, .recovery_items(names(TRUE_UTILS)),
                            list(), verbose = FALSE)

  pop <- res$population_utilities
  est <- pop$HB_Utility_Mean[match(names(TRUE_UTILS), pop$Item_ID)]
  rho <- cor(est, TRUE_UTILS, method = "spearman")
  expect_gt(rho, 0.9)
})

# ------------------------------------------------------------------------------
# Counts math, hand-computed
# ------------------------------------------------------------------------------

.counts_fixture_long <- function(weights = c(R1 = 1, R2 = 1)) {
  # Two respondents, one task each, items A/B/C shown.
  # R1: best A, worst C.  R2: best A, worst B.
  rows <- list()
  for (r in names(weights)) {
    best <- "A"; worst <- if (r == "R1") "C" else "B"
    for (item in c("A", "B", "C")) {
      rows[[length(rows) + 1]] <- data.frame(
        resp_id = r, version = 1L, task = 1L, item_id = item,
        position = match(item, c("A", "B", "C")),
        is_best = as.integer(item == best),
        is_worst = as.integer(item == worst),
        weight = unname(weights[r]), stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  out$obs_id <- seq_len(nrow(out))
  out
}

test_that("counts math matches hand computation, unweighted", {
  long <- .counts_fixture_long()
  counts <- compute_maxdiff_counts(long, .recovery_items(c("A", "B", "C")),
                                   weighted = FALSE, verbose = FALSE)

  a <- counts[counts$Item_ID == "A", ]
  b <- counts[counts$Item_ID == "B", ]
  c_ <- counts[counts$Item_ID == "C", ]

  # A: shown twice, best twice, worst never -> Best% 100, Worst% 0, Net 100.
  expect_equal(a$Times_Shown, 2)
  expect_equal(a$Best_Pct, 100)
  expect_equal(a$Worst_Pct, 0)
  expect_equal(a$Net_Score, 100)
  # B: shown twice, worst once -> Worst% 50, Net -50.
  expect_equal(b$Best_Pct, 0)
  expect_equal(b$Worst_Pct, 50)
  expect_equal(b$Net_Score, -50)
  expect_equal(c_$Net_Score, -50)
})

test_that("counts math matches hand computation, weighted", {
  # R1 weight 3, R2 weight 1.
  long <- .counts_fixture_long(weights = c(R1 = 3, R2 = 1))
  counts <- compute_maxdiff_counts(long, .recovery_items(c("A", "B", "C")),
                                   weighted = TRUE, verbose = FALSE)

  a <- counts[counts$Item_ID == "A", ]
  b <- counts[counts$Item_ID == "B", ]
  c_ <- counts[counts$Item_ID == "C", ]

  # Weighted shown = 4 per item. A best-weight = 4 -> 100%.
  expect_equal(a$Best_Pct, 100)
  # B worst only for R2 (weight 1) -> 1/4 = 25%. C worst for R1 (3) -> 75%.
  expect_equal(b$Worst_Pct, 25)
  expect_equal(c_$Worst_Pct, 75)
  expect_equal(b$Net_Score, -25)
  expect_equal(c_$Net_Score, -75)
})
