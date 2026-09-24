# Every spec problem is a TRS refusal with a code, never a crash or a silent fix.

refusal_code <- function(spec) {
  spec$n_boot <- 0
  r <- quietly(whatif_run_engine(spec, verbose = FALSE))
  if (is_error(r)) return(paste("UNEXPECTED ERROR:", r$message))
  if (is_refusal(r)) r$code else "NO_REFUSAL"
}

base <- whatif_synthetic_study(n = 300)

test_that("a valid spec is not refused", {
  expect_equal(refusal_code(base), "NO_REFUSAL")
})

test_that("outcome problems are refused", {
  s <- base; s$y[3] <- NA
  expect_equal(refusal_code(s), "DATA_OUTCOME_CODES")
  s <- base; s$y[3] <- 4L
  expect_equal(refusal_code(s), "DATA_OUTCOME_CODES")
  s <- base; s$outcome$score <- c(-100, 100)
  expect_equal(refusal_code(s), "CFG_OUTCOME_SCORE")
  s <- base; s$y[s$y == 2] <- 1L
  expect_equal(refusal_code(s), "DATA_OUTCOME_EMPTY_CATEGORY")
  s <- base; s$outcome <- NULL
  expect_equal(refusal_code(s), "CFG_OUTCOME_MISSING")
})

test_that("weight problems are refused", {
  s <- base; s$weights <- rep(1, 299)
  expect_equal(refusal_code(s), "DATA_WEIGHTS_INVALID")
  s <- base; s$weights <- c(0, rep(1, 299))
  expect_equal(refusal_code(s), "DATA_WEIGHTS_INVALID")
  s <- base; s$weights <- c(NA, rep(1, 299))
  expect_equal(refusal_code(s), "DATA_WEIGHTS_INVALID")
})

test_that("lever problems are refused", {
  s <- base; s$levers[[1]]$values[5] <- NA
  expect_equal(refusal_code(s), "DATA_LEVER_MISSING")
  s <- base; s$levers[[1]]$values <- s$levers[[1]]$values[-1]
  expect_equal(refusal_code(s), "DATA_LEVER_LENGTH")
  s <- base; s$levers[[1]]$values[5] <- 7
  expect_equal(refusal_code(s), "DATA_LEVER_OFF_SCALE")
  s <- base; s$levers[[2]]$key <- "teach"
  expect_equal(refusal_code(s), "CFG_LEVER_KEYS")
  s <- base; s$levers[[1]]$kind <- "score"
  expect_equal(refusal_code(s), "CFG_LEVER_KIND")
  s <- base; s$levers[[1]]$expected <- 0
  expect_equal(refusal_code(s), "CFG_LEVER_EXPECTED")
  s <- base; s$levers[[1]]$target <- 9
  expect_equal(refusal_code(s), "CFG_LEVER_TARGET")
  s <- base; s$levers[[5]]$values[1] <- 2
  expect_equal(refusal_code(s), "DATA_COVERAGE_NOT_BINARY")
  s <- base; s$levers[[4]]$has <- NULL
  expect_equal(refusal_code(s), "DATA_NESTED_HAS")
  s <- base; s$levers[[4]]$values[which(s$levers[[4]]$has)[1]] <- NA
  expect_equal(refusal_code(s), "DATA_LEVER_MISSING")
  s <- base; s$levers[[4]]$has <- rep(TRUE, 300); s$levers[[4]]$values[is.na(s$levers[[4]]$values)] <- 3
  expect_equal(refusal_code(s), "DATA_NESTED_NO_CONTRAST")
  s <- base; s$levers <- list()
  expect_equal(refusal_code(s), "CFG_NO_LEVERS")
  s <- base; s$scale$good <- 9
  expect_equal(refusal_code(s), "CFG_SCALE_INVALID")
})

test_that("context, baseline and profile problems are refused", {
  s <- base; s$context$campus$values[2] <- NA
  expect_equal(refusal_code(s), "DATA_CONTEXT_INVALID")
  s <- base; s$baselines <- "region"
  expect_equal(refusal_code(s), "CFG_CONTEXT_UNKNOWN")
  s <- base; s$profile$keys <- c(s$profile$keys, "region")
  expect_equal(refusal_code(s), "CFG_CONTEXT_UNKNOWN")
  s <- base; s$profile$structural <- c("year", "shoe_size")
  expect_equal(refusal_code(s), "CFG_STRUCTURAL_NOT_PROFILE")
})

test_that("Structure rules may not block personal traits or name unknown levels", {
  s <- base
  s$profile$rules <- rbind(s$profile$rules,
    data.frame(key1 = "gender", level1 = "Male", key2 = "year", level2 = "Masters"))
  expect_equal(refusal_code(s), "CFG_RULE_ON_PERSONAL_TRAIT")
  s <- base; s$profile$rules$level2[1] <- "Masterz"
  expect_equal(refusal_code(s), "CFG_RULE_UNKNOWN_LEVEL")
  s <- base; s$profile$rules <- data.frame(a = 1)
  expect_equal(refusal_code(s), "CFG_RULES_COLUMNS")
  s <- base; s$profile$rules$key2[1] <- "course"; s$profile$rules$level2[1] <- "BA"
  expect_equal(refusal_code(s), "CFG_RULE_SAME_TRAIT")
})

test_that("bundle and settings problems are refused", {
  s <- base; s$bundles[[1]]$moves <- c(nope = "up1")
  expect_equal(refusal_code(s), "CFG_BUNDLE_INVALID")
  s <- base; s$bundles[[1]]$moves <- c(mentor = "up1")
  expect_equal(refusal_code(s), "CFG_BUNDLE_MOVE")
  s <- base; s$folds <- 1
  expect_equal(refusal_code(s), "CFG_SETTINGS_INVALID")
  s <- base; s$penalty_grid_baselines <- c(0, 5)
  expect_equal(refusal_code(s), "CFG_PENALTY_INVALID")
})

test_that("a refusal is printed to the console with its code", {
  s <- base; s$y[1] <- NA; s$n_boot <- 0
  printed <- utils::capture.output(r <- whatif_run_engine(s, verbose = FALSE))
  expect_true(any(grepl("DATA_OUTCOME_CODES", printed)))
  expect_true(any(grepl("How to fix", printed)))
})

test_that("dk flags default to none, must match the respondents, and never apply to coverage", {
  spec <- whatif_synthetic_study(n = 200)
  g <- quietly(whatif_guard_spec(spec))
  expect_true(all(vapply(g$levers, function(lv) is.logical(lv$dk) && length(lv$dk) == 200 && !any(lv$dk), logical(1))))
  bad <- spec
  bad$levers[[1]]$dk <- c(TRUE, FALSE)
  r <- quietly(whatif_run_engine(bad, verbose = FALSE))
  expect_true(is_refusal(r))
  expect_equal(r$code, "DATA_LEVER_DK")
  cov <- spec
  cov$levers[[5]]$dk <- rep(TRUE, 200)
  g2 <- quietly(whatif_guard_spec(cov))
  expect_false(any(g2$levers[[5]]$dk))
  nest <- spec
  nest$levers[[4]]$dk <- rep(TRUE, 200)
  g3 <- quietly(whatif_guard_spec(nest))
  expect_equal(g3$levers[[4]]$dk, g3$levers[[4]]$has)
})
