# Session 2: the config workbook, the template, and building the engine spec
# from a data file the way a real study arrives.

proj <- test_project()
cfg <- whatif_read_config(proj$config)
prep <- whatif_prepare(cfg, verbose = FALSE)
d <- proj$data[proj$data$Status == "Complete", ]

test_that("the template writes every known setting, and nothing else", {
  def <- whatif_settings_def()
  names_in_template <- unlist(lapply(def, function(sec) vapply(sec$fields, `[[`, "", "name")))
  expect_setequal(names_in_template, WHATIF_KNOWN_SETTINGS)
  expect_false(anyDuplicated(names_in_template) > 0)
})

test_that("a blank template reads back and refuses only for the missing required settings", {
  f <- tempfile(fileext = ".xlsx")
  res <- suppressMessages(generate_whatif_config_template(f))
  expect_equal(res$status, "PASS")
  r <- quietly(with_refusal_handler(whatif_read_config(f), module = "WHATIF"))
  expect_true(is_refusal(r))
  expect_equal(r$code, "CFG_REQUIRED_SETTING")
})

test_that("settings, sheets and types read back from a written config", {
  s <- cfg$settings
  expect_equal(s$id_variable, "ID")
  expect_equal(s$base_filter_values, "Complete")
  expect_equal(s$outcome_bands, c("0-6", "7-8", "9-10"))
  expect_equal(s$outcome_scores, c(-100, 0, 100))
  expect_identical(s$min_group, 5)
  expect_true(s$profile_builder)
  expect_equal(nrow(cfg$levers), 7)
  expect_equal(cfg$sentence$Key, c("gender", "year", "course", "campus", NA))
  expect_equal(cfg$bundles$Moves, "teach=up1; admin=up1")
})

test_that("the base filter drops the partial interviews", {
  expect_equal(prep$dropped$n_file, 502)
  expect_equal(prep$dropped$base_filter, 2)
  expect_equal(length(prep$spec$y), 500)
  expect_false(any(grepl("^P", prep$ids)))
})

test_that("the outcome is banded from the 0 to 10 answer", {
  nps <- as.numeric(d$NPS)
  expect_equal(prep$spec$y, as.integer(ifelse(nps >= 9, 3, ifelse(nps >= 7, 2, 1))))
})

test_that("labelled ratings become scale points; two items average into one lever", {
  L5 <- c("Terrible", "Not very good", "About average", "Good", "Excellent")
  t1 <- match(d$T1, L5)
  t2 <- match(d$T2, L5)
  t2[is.na(t2)] <- round(stats::median(t2, na.rm = TRUE))
  teach <- prep$spec$levers[[1]]
  expect_equal(teach$values, (t1 + t2) / 2)
  expect_equal(teach$missing, sum(d$T2 == "DK"))
})

test_that("a DK with no index weight is don't-know even when not marked excluded", {
  expect_equal(sum(d$T2 == "DK"), 3)
  expect_false(any(prep$spec$levers[[1]]$values > 5))
})

test_that("don't-know answers take the median and are counted", {
  admin <- prep$spec$levers[[2]]
  expect_equal(admin$missing, 20)
  expect_true(all(admin$values %in% 1:5))
})

test_that("a respondent whose only answer was don't-know is flagged dk, out of the need count and the moves", {
  admin <- prep$spec$levers[[2]]
  expect_equal(sum(admin$dk), 20)
  expect_equal(which(admin$dk), which(d$A1 == "DK"))
  # The teaching lever averages T1 and T2; a DK on T2 alone still leaves a
  # rating from T1, so nobody is flagged.
  expect_false(any(prep$spec$levers[[1]]$dk))
  # A dk respondent sitting below the target (the centre fill) is not in need
  # and the floor move leaves them where they are.
  g <- quietly(whatif_guard_spec(prep$spec))
  a <- g$levers[[2]]
  expect_false(any(whatif_need_mask(a)[a$dk]))
  expect_true(all(whatif_move_delta(a, "floor", g$scale)[a$dk] == 0))
})

test_that("an either/or pair averages only the question each respondent was asked", {
  L5 <- c("Terrible", "Not very good", "About average", "Good", "Excellent")
  reg <- prep$spec$levers[[4]]
  expected <- ifelse(is.na(d$R_NEW), match(d$R_RET, L5), match(d$R_NEW, L5))
  expect_equal(reg$values, expected)
  expect_equal(reg$missing, 0)
})

test_that("a nested lever has the service only where the rating was given", {
  online <- prep$spec$levers[[5]]
  expect_equal(online$kind, "nested")
  expect_equal(online$has, !is.na(d$ONLINE))
  expect_true(all(is.na(online$values[!online$has])))
})

test_that("coverage is 0/1 from CoverageValues, and a symptom is kept aside", {
  mentor <- prep$spec$levers[[6]]
  expect_equal(mentor$values, as.numeric(d$MENTOR == "Yes"))
  expect_equal(length(prep$spec$levers), 6)
  expect_equal(prep$symptoms[[1]]$label, "Called us")
  expect_equal(prep$symptoms[[1]]$flag, as.numeric(d$CALLED == "Yes"))
})

test_that("context gets its missing label; profile, baselines and rules come from the sheets", {
  g <- prep$spec$context$gender$values
  expect_equal(sum(g == "Not said"), sum(is.na(d$GENDER)))
  expect_equal(prep$spec$profile$keys, c("gender", "year", "course", "campus"))
  expect_equal(prep$spec$profile$structural, c("campus", "course", "year"))
  expect_equal(prep$spec$profile$rules$level2, "Masters")
  expect_setequal(prep$spec$baselines, c("campus", "course", "year", "gender"))
  expect_equal(prep$spec$bundles[[1]]$moves, c(teach = "up1", admin = "up1"))
})

test_that("recodes, BoxCategory, DisplayText and collapsing each shape a context variable", {
  row <- list(Key = "year", Question = "YEAR", Levels = NA, CollapseUnder = NA, CollapseLabel = NA,
              MissingLabel = NA)
  rc <- data.frame(Key = "year", From = c("Honours", "Masters"), To = "Postgrad", stringsAsFactors = FALSE)
  v <- whatif_context_values(row, d$YEAR, prep$options$YEAR, rc)
  expect_setequal(unique(v), c("1st", "2nd", "3rd", "Postgrad"))
  row$Levels <- "box"
  v <- whatif_context_values(row, d$YEAR, prep$options$YEAR, rc[0, ])
  expect_setequal(unique(v), c("Undergrad", "Postgrad"))
  row$Levels <- "display"
  v <- whatif_context_values(row, d$YEAR, prep$options$YEAR, rc[0, ])
  expect_true("First" %in% v)
  row$Levels <- NA; row$CollapseUnder <- "60"; row$CollapseLabel <- "Rest"
  v <- whatif_context_values(row, d$YEAR, prep$options$YEAR, rc[0, ])
  small <- names(table(d$YEAR))[table(d$YEAR) < 60]
  expect_true(all(v[d$YEAR %in% small] == "Rest"))
})

test_that("a numeric answer keeps its number and a byte-order mark is stripped from headers", {
  s <- whatif_score_answers(c("0", "10", "7"), data.frame(text = as.character(0:10), excluded = FALSE))
  expect_equal(s$value, c(0, 10, 7))
  f <- tempfile(fileext = ".csv")
  writeLines(c("﻿Response ID,Q1", "a,1"), f, useBytes = TRUE)
  expect_equal(names(whatif_load_data(f))[1], "Response ID")
})

test_that("config mistakes are refused with their own codes", {
  code_for <- function(settings = list(), ...) {
    dir <- tempfile("cfg_"); dir.create(dir)
    suppressMessages(utils::capture.output(p <- whatif_write_test_project(dir, n = 200, config = settings)))
    r <- quietly(run_whatif(p$config, verbose = FALSE))
    if (is_error(r)) return(paste("ERROR", r$message))
    if (is_refusal(r)) r$code else "NO_REFUSAL"
  }
  expect_equal(code_for(list(id_variable = "NOPE")), "DATA_COLUMN_MISSING")
  expect_equal(code_for(list(outcome_bands = "0-6; 7-8")), "CFG_OUTCOME_BANDS")
  expect_equal(code_for(list(dont_know = "zero")), "CFG_DONT_KNOW")
  expect_equal(code_for(list(scale_max = 4)), "DATA_LEVER_OFF_SCALE")
  expect_equal(code_for(list(min_group = 1)), "CFG_SETTING_NOT_NUMBER")
  expect_equal(code_for(list(weight_variable = "NPS")), "DATA_WEIGHTS_INVALID")
  expect_equal(code_for(list(base_filter_values = "Complete; Partial")), "NO_REFUSAL")
})

test_that("with the centre rule a don't-know fill sits below the target and is still out of the need count", {
  p2 <- test_project(config = list(dont_know = "centre"))
  prep2 <- whatif_prepare(whatif_read_config(p2$config), verbose = FALSE)
  g <- quietly(whatif_guard_spec(prep2$spec))
  a <- g$levers[[2]]
  expect_equal(a$key, "admin")
  expect_equal(sum(a$dk), 20)
  expect_true(all(a$values[a$dk] == 3))
  # The fill is below Good, so without the flag these 20 would count as needing the fix.
  expect_equal(sum(a$values < a$target), sum(whatif_need_mask(a)) + 20)
  expect_true(all(whatif_move_delta(a, "floor", g$scale)[a$dk] == 0))
})
