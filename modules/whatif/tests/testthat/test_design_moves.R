# Design matrix for the three lever kinds and baselines; the moves.

sc <- list(min = 1, max = 5, centre = 3, good = 4)
rating <- list(key = "r", kind = "rating", values = c(1, 2, 3, 4, 5), target = 4)
nested <- list(key = "n", kind = "nested", values = c(1, NA, 3, NA, 5),
               has = c(TRUE, FALSE, TRUE, FALSE, TRUE), target = 4)
coverage <- list(key = "c", kind = "coverage", values = c(0, 1, 0, 1, 1))
ctx <- list(site = list(label = "Site", values = c("A", "B", "A", "C", "A")))

test_that("rating is centred, nested has two columns, coverage is 0/1", {
  d <- whatif_build_design(list(rating, nested, coverage), sc)
  expect_equal(colnames(d$X), c("r_val", "n_has", "n_val", "c_val"))
  expect_equal(unname(d$X[, "r_val"]), c(-2, -1, 0, 1, 2))
  expect_equal(unname(d$X[, "n_has"]), c(1, 0, 1, 0, 1))
  expect_equal(unname(d$X[, "n_val"]), c(-2, 0, 0, 0, 2))
  expect_equal(unname(d$X[, "c_val"]), c(0, 1, 0, 1, 1))
  expect_equal(unname(d$lever_col), c(1, 3, 4))
  expect_false(any(d$cols$is_context))
})

test_that("baselines add one dummy per non-reference level, most common level as reference", {
  d <- whatif_build_design(list(rating), sc, ctx, "site")
  expect_equal(d$baseline_levels$site, c("A", "B", "C"))
  expect_equal(colnames(d$X), c("r_val", "site_B", "site_C"))
  expect_equal(d$cols$is_context, c(FALSE, TRUE, TRUE))
  expect_equal(unname(d$X[, "site_B"]), c(0, 1, 0, 0, 0))
})

test_that("levels by frequency break ties alphabetically", {
  expect_equal(whatif_levels_by_frequency(c("b", "a", "c", "c")), c("c", "a", "b"))
})

test_that("rating moves clip to the scale", {
  expect_equal(whatif_move_delta(rating, "slip1", sc), c(0, -1, -1, -1, -1))
  expect_equal(whatif_move_delta(rating, "slip2", sc), c(0, -1, -2, -2, -2))
  expect_equal(whatif_move_delta(rating, "up1", sc), c(1, 1, 1, 1, 0))
  expect_equal(whatif_move_delta(rating, "up2", sc), c(2, 2, 2, 1, 0))
})

test_that("floor lifts only those below the lever's target, to the target", {
  expect_equal(whatif_move_delta(rating, "floor", sc), c(3, 2, 1, 0, 0))
  r8 <- modifyList(rating, list(target = 5))
  expect_equal(whatif_move_delta(r8, "floor", sc), c(4, 3, 2, 1, 0))
})

test_that("nested moves touch only respondents who have the service", {
  expect_equal(whatif_move_delta(nested, "up1", sc), c(1, 0, 1, 0, 0))
  expect_equal(whatif_move_delta(nested, "floor", sc), c(3, 0, 1, 0, 0))
  expect_equal(whatif_move_delta(nested, "slip1", sc), c(0, 0, -1, 0, -1))
})

test_that("coverage extends and withdraws; rating moves do not apply to it", {
  expect_equal(whatif_move_delta(coverage, "extend", sc), c(1, 0, 1, 0, 0))
  expect_equal(whatif_move_delta(coverage, "withdraw", sc), c(0, -1, 0, -1, -1))
  expect_null(whatif_move_delta(coverage, "up1", sc))
  expect_null(whatif_move_delta(rating, "extend", sc))
})

test_that("need counts those a fix would reach", {
  expect_equal(whatif_need_mask(rating), c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(whatif_need_mask(nested), c(TRUE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(whatif_need_mask(coverage), c(TRUE, FALSE, TRUE, FALSE, FALSE))
})
