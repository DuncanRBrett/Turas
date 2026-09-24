# The profile model ("Build a student") and the Structure rules.

model <- fixture_model(n_boot = 20)

test_that("the profile model is fitted with a penalty from the grid", {
  pm <- model$profile
  expect_false(is.null(pm))
  expect_true(pm$penalty %in% WHATIF_PROFILE_PENALTIES)
  expect_length(pm$fits, 21)
  expect_length(pm$spread, 3)
  expect_true(pm$spread[1] <= pm$spread[2] && pm$spread[2] <= pm$spread[3])
})

test_that("a possible profile gets an estimate with a range", {
  p <- whatif_profile_predict(model, c(gender = "Female", year = "2nd", course = "BA", campus = "North"))
  expect_false(is_refusal(p))
  expect_named(p, c("est", "lo", "hi"))
  expect_true(p[["lo"]] <= p[["hi"]])
  expect_true(p[["est"]] > -100 && p[["est"]] < 100)
})

test_that("the engine refuses a profile the Structure rules block", {
  p <- quietly(whatif_profile_predict(model, c(gender = "Female", year = "Masters", course = "BA", campus = "North")))
  expect_true(is_refusal(p))
  expect_equal(p$code, "CFG_PROFILE_IMPOSSIBLE")
  q <- quietly(whatif_profile_predict(model, c(gender = "Male", year = "1st", course = "MSc", campus = "Online")))
  expect_true(is_refusal(q))
  expect_equal(q$code, "CFG_PROFILE_IMPOSSIBLE")
})

test_that("a combination nobody has on personal traits is still answered", {
  # Drop every male Masters student: the combination is now unseen, and no
  # Structure rule may block it because gender is a personal trait.
  spec <- whatif_synthetic_study()
  keep <- !(spec$context$gender$values == "Male" & spec$context$year$values == "Masters")
  spec$y <- spec$y[keep]
  spec$levers <- lapply(spec$levers, function(lv) {
    lv$values <- lv$values[keep]
    if (!is.null(lv$has)) lv$has <- lv$has[keep]
    lv
  })
  spec$context <- lapply(spec$context, function(cx) { cx$values <- cx$values[keep]; cx })
  spec$n_boot <- 5
  m <- quietly(whatif_run_engine(spec, verbose = FALSE))
  expect_s3_class(m, "whatif_model")
  expect_false(any(m$spec$context$gender$values == "Male" & m$spec$context$year$values == "Masters"))
  p <- whatif_profile_predict(m, c(gender = "Male", year = "Masters", course = "MSc", campus = "Online"))
  expect_false(is_refusal(p))
  expect_true(is.finite(p[["est"]]))
})

test_that("an unknown level or a missing trait is refused", {
  a <- quietly(whatif_profile_predict(model, c(gender = "Female", year = "5th", course = "BA", campus = "North")))
  expect_equal(a$code, "CFG_PROFILE_LEVEL")
  b <- quietly(whatif_profile_predict(model, c(gender = "Female", year = "2nd", course = "BA")))
  expect_equal(b$code, "CFG_PROFILE_KEYS")
})

test_that("the profile estimate is the model's prediction for those dummies", {
  pm <- model$profile
  prof <- c(gender = "Male", year = "3rd", course = "BCom", campus = "South")
  x <- as.numeric(prof[pm$cols$key] == pm$cols$level)
  hand <- whatif_score_vec(pm$fits[[1]], sum(x * pm$fits[[1]]$b), c(-100, 0, 100))
  expect_equal(whatif_profile_predict(model, prof)[["est"]], hand)
})

test_that("a model run without a profile refuses profile questions", {
  spec <- whatif_synthetic_study()
  spec$profile <- NULL
  spec$n_boot <- 5
  m <- quietly(whatif_run_engine(spec, verbose = FALSE))
  expect_s3_class(m, "whatif_model")
  expect_null(m$profile)
  p <- quietly(whatif_profile_predict(m, c(gender = "Male")))
  expect_equal(p$code, "CFG_PROFILE_OFF")
})
