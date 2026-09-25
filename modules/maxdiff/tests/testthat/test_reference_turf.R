# ==============================================================================
# MAXDIFF - REFERENCE GATE: TURF
# ==============================================================================
# The MaxDiff TURF wrapper (R/11_turf.R) over the shared engine, checked on a
# five-respondent design worked by hand. The engine itself lives in
# modules/shared/lib/turf_engine.R and is not edited from this module.
#
# Utilities (A, B, C, D) and the ABOVE_MEAN appeal they give (each row's
# mean is 0, so an item appeals when its utility is above 0):
#   R1 ( 1,  1, -1, -1)  -> A B
#   R2 ( 3, -1, -1, -1)  -> A
#   R3 (-1, -1,  3, -1)  -> C
#   R4 (-1, -1,  1,  1)  -> C D
#   R5 (-1,  1, -1,  1)  -> B D
# ==============================================================================

.turf_utils <- function() {
  data.frame(resp_id = paste0("R", 1:5),
             A = c(1, 3, -1, -1, -1), B = c(1, -1, -1, -1, 1),
             C = c(-1, -1, 3, 1, -1), D = c(-1, -1, -1, 1, 1))
}
.turf_items <- function() {
  data.frame(Item_ID = c("A", "B", "C", "D"), Item_Label = paste("Item", c("A", "B", "C", "D")),
             Include = 1L, stringsAsFactors = FALSE)
}

test_that("unweighted ABOVE_MEAN TURF matches the hand-worked greedy path", {
  # Step 1: every item reaches 2 of 5; the first (A) wins the tie. 40%.
  # Step 2: A+B 3/5, A+C 4/5, A+D 4/5 -> C (first of the tie). 80%, +40.
  # Step 3: A+C+B 5/5, A+C+D 5/5 -> B. 100%, +20. Stops at 100%.
  # Frequency (mean appealing items in the portfolio): 0.4, 0.8, 1.2.
  r <- run_turf_analysis(.turf_utils(), .turf_items(), max_items = 4,
                         threshold_method = "ABOVE_MEAN", verbose = FALSE)
  t <- r$incremental_table
  expect_equal(t$Item_ID, c("A", "C", "B"))
  expect_equal(t$Reach_Pct, c(40, 80, 100))
  expect_equal(t$Incremental_Pct, c(40, 40, 20))
  expect_equal(t$Frequency, c(0.4, 0.8, 1.2))
  expect_equal(t$Item_Label[1], "Item A")
})

test_that("weighted TURF matches the hand-worked path and ignores the weight scale", {
  # Weights (1, 1, 1, 1, 4), total 8.
  # Step 1: A 2/8, B 5/8, C 2/8, D 5/8 -> B. 62.5%.
  # Step 2: B+A 6/8, B+C 7/8, B+D 6/8 -> C. 87.5%, +25.
  # Step 3: B+C+A 8/8 -> A. 100%, +12.5.
  # Frequency: (1+4)/8 = 0.625, (1+1+1+4)/8 = 0.875, (2+1+1+1+4)/8 = 1.125.
  w <- c(1, 1, 1, 1, 4)
  for (scale in c(1, 1000)) {
    r <- run_turf_analysis(.turf_utils(), .turf_items(), max_items = 4,
                           threshold_method = "ABOVE_MEAN", weights = w * scale,
                           verbose = FALSE)
    t <- r$incremental_table
    expect_equal(t$Item_ID, c("B", "C", "A"))
    expect_equal(t$Reach_Pct, c(62.5, 87.5, 100))
    expect_equal(t$Incremental_Pct, c(62.5, 25, 12.5))
    expect_equal(t$Frequency, c(0.625, 0.875, 1.125), tolerance = 0.006)
  }
})

test_that("TOP_3 appeal is each respondent's three highest items", {
  # Five items; ties broken by column order (rank ties.method = "first").
  #   R1 (5, 4, 3, 2, 1) -> A B C
  #   R2 (1, 2, 3, 4, 5) -> C D E
  #   R3 (0, 0, 0, 0, 9) -> E A B   (ties among the zeros go to A, B)
  s <- rbind(c(5, 4, 3, 2, 1), c(1, 2, 3, 4, 5), c(0, 0, 0, 0, 9))
  colnames(s) <- c("A", "B", "C", "D", "E")
  ap <- classify_appeal(s, method = "TOP_3")
  expect_equal(unname(ap[1, ]), c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(unname(ap[2, ]), c(FALSE, FALSE, TRUE, TRUE, TRUE))
  expect_equal(unname(ap[3, ]), c(TRUE, TRUE, FALSE, FALSE, TRUE))
})

test_that("a numeric resp_id column never becomes an item", {
  u <- .turf_utils(); u$resp_id <- 10001:10005
  r <- run_turf_analysis(u, .turf_items(), max_items = 4,
                         threshold_method = "ABOVE_MEAN", verbose = FALSE)
  expect_false("resp_id" %in% r$incremental_table$Item_ID)
  expect_equal(r$incremental_table$Reach_Pct, c(40, 80, 100))
})

test_that("ABOVE_MEAN is strictly above the respondent's own mean", {
  # Row (1, 0, -1) has mean 0: only the first item is above it. The middle
  # item sits ON the mean and does not appeal.
  s <- rbind(c(1, 0, -1)); colnames(s) <- c("A", "B", "C")
  expect_equal(unname(classify_appeal(s, method = "ABOVE_MEAN")[1, ]), c(TRUE, FALSE, FALSE))
})
