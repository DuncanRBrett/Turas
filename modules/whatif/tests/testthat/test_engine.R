# The engine end to end on the synthetic study: fit, refits, sign check, group
# results, bundles and calibration.

model <- fixture_model()

test_that("the engine runs and recovers the direction of every real effect", {
  expect_s3_class(model, "whatif_model")
  expect_true(model$status %in% c("PASS", "PARTIAL"))
  b <- model$main$b
  expect_gt(b[["teach_val"]], 0.6)
  expect_gt(b[["online_val"]], 0.2)
  expect_gt(b[["mentor_val"]], 0.3)
  expect_lt(abs(b[["noise_val"]]), 0.2)
  expect_length(model$boot, 30)
})

test_that("the sign check separates a strong lever from a pure-noise one", {
  s <- model$sign
  expect_equal(s$wrong_share[s$key == "teach"], 0)
  expect_equal(s$wrong_share[s$key == "mentor"], 0)
  expect_gt(s$wrong_share[s$key == "noise"], 0.1)
  expect_true(s$unclear[s$key == "noise"])
  expect_equal(model$status, "PARTIAL")
  expect_true(any(grepl("Sign check", model$warnings)))
})

test_that("an expected direction of -1 flips the sign check", {
  spec <- whatif_synthetic_study()
  spec$levers[[1]]$expected <- -1
  spec$n_boot <- 10
  m <- quietly(whatif_run_engine(spec, verbose = FALSE))
  expect_equal(m$sign$wrong_share[m$sign$key == "teach"], 1)
})

test_that("refits are reproducible and leave the caller's random stream alone", {
  spec <- whatif_synthetic_study()  # the generator seeds R itself, so build it first
  spec$n_boot <- 30
  set.seed(99)
  before <- runif(1)
  set.seed(99)
  m2 <- quietly(whatif_run_engine(spec, verbose = FALSE))
  after <- runif(1)
  expect_identical(before, after)
  expect_identical(m2$boot[[7]]$b, model$boot[[7]]$b)
})

test_that("group results: actual score, signs of moves, ranges and reach", {
  spec <- model$spec
  masks <- list(all = rep(TRUE, length(spec$y)),
                honours = spec$context$year$values == "Honours")
  res <- whatif_group_results(model, masks)
  y <- spec$y
  expect_equal(res$all$actual, 100 * (mean(y == 3) - mean(y == 1)))
  expect_equal(res$all$n, length(y))
  lv <- res$all$levers
  teach <- lv[lv$key == "teach", ]
  expect_gt(teach$est[teach$move == "up1"], 0)
  expect_lt(teach$est[teach$move == "slip1"], 0)
  expect_lt(teach$est[teach$move == "slip2"], teach$est[teach$move == "slip1"])
  expect_true(all(teach$lo <= teach$est + 1e-9 | is.na(teach$lo)))
  fl <- teach[teach$move == "floor", ]
  expect_equal(fl$need, sum(spec$levers[[1]]$values < 4))
  expect_equal(fl$per_100, fl$est * length(y) / fl$need)
  expect_equal(sort(unique(lv$move[lv$key == "mentor"])), c("extend", "withdraw"))
  expect_equal(res$honours$n, sum(masks$honours))
})

test_that("a group's gain is the weighted mean of respondent-level changes", {
  m <- fixture_model(weighted = TRUE)
  spec <- m$spec
  mask <- spec$context$campus$values == "South"
  res <- whatif_group_results(m, list(south = mask))
  eta <- drop(m$design$X %*% m$main$b)
  base <- whatif_score_vec(m$main, eta, spec$outcome$score)
  after <- whatif_score_vec(m$main, eta + m$main$b[["admin_val"]] * m$deltas$admin$up1, spec$outcome$score)
  hand <- stats::weighted.mean(after[mask] - base[mask], spec$weights[mask])
  got <- res$south$levers
  expect_equal(got$est[got$key == "admin" & got$move == "up1"], hand, tolerance = 1e-10)
})

test_that("a one-lever bundle equals that lever's move; a bundle is exact, not a sum", {
  res <- whatif_group_results(model, list(all = rep(TRUE, length(model$spec$y))))
  lv <- res$all$levers
  expect_equal(res$all$bundles$est[1], lv$est[lv$key == "teach" & lv$move == "up1"], tolerance = 1e-10)
  parts <- lv$est[lv$key == "teach" & lv$move == "up1"] + lv$est[lv$key == "admin" & lv$move == "up1"] +
    lv$est[lv$key == "mentor" & lv$move == "extend"]
  expect_false(isTRUE(all.equal(res$all$bundles$est[2], parts)))
  expect_lt(abs(res$all$bundles$est[2] - parts), 5)
})

test_that("an empty group is refused, not reported as zero", {
  res <- quietly(whatif_group_results(model, list(none = rep(FALSE, length(model$spec$y)))))
  expect_true(is_refusal(res))
  expect_equal(res$code, "DATA_GROUP_EMPTY")
})

test_that("group definitions become masks; an unknown variable is refused", {
  masks <- whatif_group_masks(model$spec$context, list(all = character(0), ba = c(course = "BA")))
  expect_true(all(masks$all))
  expect_equal(sum(masks$ba), sum(model$spec$context$course$values == "BA"))
  expect_error(quietly(whatif_group_masks(model$spec$context, list(x = c(nope = "A")))),
               class = "turas_refusal")
})

test_that("context baselines fix a group the ratings cannot explain", {
  # A clear Honours offset and a larger sample: at n = 900 and -0.9 some seeds
  # leave cross-validation preferring heavy shrinkage, which is honest but
  # makes a poor test.
  off <- whatif_calibration(fixture_model(n = 1500, honours_offset = -1.2, n_boot = 0))
  on_model <- fixture_model(n = 1500, honours_offset = -1.2, n_boot = 0,
                            baselines = c("campus", "course", "year", "gender"))
  on <- whatif_calibration(on_model)
  z_off <- off$table$z[off$table$level == "Honours"]
  z_on <- on$table$z[on$table$level == "Honours"]
  expect_gt(abs(z_off), 1.96)
  expect_lt(abs(z_on), 1.96)
  expect_gt(on$cv_r2, off$cv_r2)
  expect_true(on_model$baseline_penalty %in% on_model$spec$penalty_grid_baselines)
  expect_equal(on_model$penalty[!on_model$design$cols$is_context],
               rep(WHATIF_LEVER_PENALTY, sum(!on_model$design$cols$is_context)))
  expect_true(all(on_model$penalty[on_model$design$cols$is_context] == on_model$baseline_penalty))
})

test_that("the calibration table skips groups under the minimum", {
  cal <- whatif_calibration(model, min_n = 150)
  expect_true(all(cal$table$n >= 150))
  expect_equal(cal$n_groups, nrow(cal$table))
})

test_that("a spec without a profile runs (no partial match on another setting)", {
  spec <- whatif_synthetic_study(n = 300)
  spec$profile <- NULL
  spec$baselines <- "year"
  spec$n_boot <- 0
  m <- quietly(whatif_run_engine(spec, verbose = FALSE))
  expect_s3_class(m, "whatif_model")
  expect_null(m$profile)
  expect_false(is.na(m$baseline_penalty))
})
