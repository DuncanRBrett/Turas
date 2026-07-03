# ==============================================================================
# TABS MODULE - TRACKING ISLAND ASSEMBLER TESTS (data-centric report v2, opt 3)
# ==============================================================================
#
# Known-answer tests for the tabs-integrated tracker's island assembler
# (modules/tabs/lib/tracking_island.R):
#   - tracking_norm mirrors the renderer's model.norm (cross-wave matching key)
#   - wave_order_key (config wave_order, else year parsed from the wave label)
#   - wave_contribution shape from a data layer + microdata
#   - build_tracking_island orders waves and flags the current one
#   - write/read contribution sidecar round-trip (forward path)
#
# The engine recompute that consumes the island is gated in the prototype node
# suite (run_tests_v2.mjs multi-wave + scores known answers).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_tracking_island.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/tabs/lib/tracking_island.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

ti_data_layer <- function() list(questions = list(
  list(code = "Q1", title = "Overall rating", type = "scale"),
  list(code = "Q2", title = "Recommend (NPS)", type = "nps"),
  list(code = "Q3", title = "No scores here", type = "single")))

ti_micro <- function() list(
  n = 3,
  scores = list(Q1 = I(c(6, 8, 7)), Q2 = I(c(100, 100, -100))),  # Q3 has no scores
  weights = I(c(1, 1, 1)))

# ==============================================================================
# 1. normalisation + order key
# ==============================================================================

context("tracking_island: norm + order key")

test_that("tracking_norm lower-cases, collapses whitespace, strips punctuation", {
  expect_equal(tracking_norm("  Overall   Rating! "), "overall rating")
  expect_equal(tracking_norm("Recommend (NPS)"), "recommend nps")
  expect_equal(tracking_norm(NULL), "")
})

test_that("wave_order_key prefers explicit wave_order", {
  expect_equal(wave_order_key(list(wave_order = 2025.5, wave = "Wave 24 - 2025")), 2025.5)
})

test_that("wave_order_key derives a year from the wave label when no wave_order", {
  expect_equal(wave_order_key(list(wave = "Annual 2024")), 2024)
  expect_true(is.na(wave_order_key(list(wave = "Pilot"))))
})

# ==============================================================================
# 2. wave_contribution
# ==============================================================================

context("tracking_island: wave_contribution")

test_that("wave_contribution carries only metrics that have scores", {
  contrib <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 1", wave_order = 2024))
  expect_equal(length(contrib$questions), 2)        # Q1, Q2 — not Q3
  codes <- vapply(contrib$questions, function(q) q$title, character(1))
  expect_setequal(codes, c("Overall rating", "Recommend (NPS)"))
})

test_that("wave_contribution sets match_key, score_type, base and the scores", {
  contrib <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 1", wave_order = 2024))
  q1 <- Find(function(q) q$title == "Overall rating", contrib$questions)
  q2 <- Find(function(q) q$title == "Recommend (NPS)", contrib$questions)
  expect_equal(q1$match_key, tracking_norm("Overall rating"))
  expect_equal(q1$score_type, "mean")
  expect_equal(q1$base, 3)
  expect_equal(as.numeric(q1$scores), c(6, 8, 7))
  expect_equal(q2$score_type, "nps")
})

test_that("wave_contribution drops NA scores and counts the base accordingly", {
  micro <- list(n = 3, scores = list(Q1 = I(c(6, NA, 8))), weights = I(c(1, 1, 1)))
  dl <- list(questions = list(list(code = "Q1", title = "Overall rating", type = "scale")))
  contrib <- wave_contribution(dl, micro, list(wave = "W", wave_order = 2024))
  expect_equal(contrib$questions[[1]]$base, 2)
  expect_equal(as.numeric(contrib$questions[[1]]$scores), c(6, 8))
})

test_that("wave_contribution returns NULL when no metric carries scores", {
  expect_null(wave_contribution(ti_data_layer(),
              list(n = 3, scores = list(), weights = I(c(1, 1, 1))),
              list(wave = "W")))
})

test_that("wave_contribution carries the question code and per-respondent weights", {
  micro <- list(n = 3, scores = list(Q1 = I(c(6, 8, 7))), weights = I(c(2, 1, 1)))
  dl <- list(questions = list(list(code = "Q1", title = "Overall rating", type = "scale")))
  contrib <- wave_contribution(dl, micro, list(wave = "W", wave_order = 2024))
  q <- contrib$questions[[1]]
  expect_equal(q$code, "Q1")                       # code carried so waves link
  expect_equal(as.numeric(q$weights), c(2, 1, 1))  # weights carried (weighted trend)
})

test_that("wave_contribution omits weights when the study is unweighted", {
  contrib <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "W", wave_order = 2024))
  expect_null(contrib$questions[[1]]$weights)       # all-1 weights -> omitted
})

# ==============================================================================
# 5. question mapping (curated cross-wave link)
# ==============================================================================

context("tracking_island: question mapping")

ti_mapping <- function() data.frame(
  QuestionCode  = c("Track_01", "Track_02", "Track_12"),
  QuestionText  = c("Overall rating", "Appearance", "Recommend"),
  QuestionType  = c("Rating", "Rating", "NPS"),
  Wave24        = c("Q32", "Q36", "Q60"),     # prior wave used different codes (renames)
  Wave25        = c("Q20", "Q23", "Q51"),     # this wave's codes match the data layer
  TrackingSpecs = c("mean", "mean", "nps_score"),
  stringsAsFactors = FALSE)

ti_dl_coded <- function() list(questions = list(
  list(code = "Q20", title = "How would you rate overall?", type = "scale"),
  list(code = "Q51", title = "Likely to recommend?", type = "nps"),
  list(code = "Q99", title = "Untracked", type = "single")))

test_that("detect_wave_column finds the column matching this wave's codes", {
  expect_equal(detect_wave_column(ti_mapping(), ti_dl_coded()), "Wave25")
})

test_that("tracking_metrics uses the canonical key + this wave's code from the mapping", {
  m <- tracking_metrics(ti_dl_coded(), ti_mapping())
  # Q20 + Q51 are present; Q23 is not in the data layer -> dropped; Q99 untracked
  codes <- vapply(m, function(x) x$code, character(1))
  expect_setequal(codes, c("Q20", "Q51"))
  q20 <- Find(function(x) x$code == "Q20", m)
  expect_equal(q20$key, tracking_norm("Track_01"))   # canonical, not the title
  q51 <- Find(function(x) x$code == "Q51", m)
  expect_equal(q51$score_type, "nps")                # from TrackingSpecs
})

test_that("tracking_metrics falls back to title-match when no mapping", {
  m <- tracking_metrics(ti_dl_coded(), NULL)
  q20 <- Find(function(x) x$code == "Q20", m)
  expect_equal(q20$key, tracking_norm("How would you rate overall?"))
})

# ==============================================================================
# 3. build_tracking_island
# ==============================================================================

context("tracking_island: assembly")

test_that("build_tracking_island orders by year and flags the current wave", {
  prior <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 1", wave_order = 2024))
  current <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 2", wave_order = 2025))
  island <- build_tracking_island(current, list(prior))
  expect_equal(island$schema_version, 1)
  expect_equal(island$kind, "tracking_microdata")
  expect_equal(vapply(island$waves, function(w) w$wave, character(1)), c("Wave 1", "Wave 2"))
  expect_false(isTRUE(island$waves[[1]]$current))
  expect_true(isTRUE(island$waves[[2]]$current))
})

test_that("twice-yearly waves order by their decimal key without colliding", {
  mk <- function(name, ord) wave_contribution(ti_data_layer(), ti_micro(),
                                              list(wave = name, wave_order = ord))
  island <- build_tracking_island(mk("May 2025", 2025),
                                  list(mk("Oct 2024", 2024), mk("Oct 2025", 2025.5)))
  expect_equal(vapply(island$waves, function(w) w$wave, character(1)),
               c("Oct 2024", "May 2025", "Oct 2025"))
})

test_that("build_tracking_island returns NULL without a current contribution", {
  expect_null(build_tracking_island(NULL, list()))
})

# ==============================================================================
# 4. sidecar round-trip (the forward path)
# ==============================================================================

context("tracking_island: sidecar round-trip")

test_that("a written contribution reads back with its metrics intact", {
  contrib <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 1", wave_order = 2024))
  dir <- tempfile("waves_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  write_wave_contribution(contrib, file.path(dir, "proj_w1_wave.json"))
  priors <- read_wave_contributions(dir)
  expect_equal(length(priors), 1)
  expect_equal(priors[[1]]$wave, "Wave 1")
  expect_equal(length(priors[[1]]$questions), 2)
})

test_that("read_wave_contributions skips the current run's own file", {
  contrib <- wave_contribution(ti_data_layer(), ti_micro(), list(wave = "Wave 1", wave_order = 2024))
  dir <- tempfile("waves_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  own <- file.path(dir, "proj_current_wave.json")
  write_wave_contribution(contrib, own)
  expect_equal(length(read_wave_contributions(dir, exclude_path = own)), 0)
})

test_that("read_wave_contributions returns empty for a missing source", {
  expect_equal(length(read_wave_contributions("")), 0)
  expect_equal(length(read_wave_contributions("/no/such/dir")), 0)
})

# ==============================================================================
# 6. audit fixes: duplicate titles + stale-wave dedupe
# ==============================================================================

context("tracking_island: duplicate normalised titles")

test_that("no-mapping metrics occurrence-suffix duplicate titles (mirrors 22w ensureIndexes)", {
  dl <- list(questions = list(
    list(code = "Q1", title = "Overall rating", type = "scale"),
    list(code = "Q2", title = "Overall  Rating!", type = "scale"),   # same normalised title
    list(code = "Q3", title = "Overall rating", type = "scale")))
  out <- capture.output(m <- tracking_metrics(dl))
  keys <- vapply(m, function(x) x$key, character(1))
  expect_equal(keys, c("overall rating", "overall rating#1", "overall rating#2"))
  expect_true(any(grepl("duplicate normalised question title", out)))
})

test_that("unique titles stay unsuffixed with no warning", {
  out <- capture.output(m <- tracking_metrics(ti_data_layer()))
  keys <- vapply(m, function(x) x$key, character(1))
  expect_equal(keys, c("overall rating", "recommend nps", "no scores here"))
  expect_false(any(grepl("duplicate", out)))
})

test_that("duplicate-title questions keep their OWN scores in the contribution", {
  dl <- list(questions = list(
    list(code = "Q1", title = "Overall rating", type = "scale"),
    list(code = "Q2", title = "Overall rating", type = "scale")))
  micro <- list(n = 2, scores = list(Q1 = I(c(6, 8)), Q2 = I(c(1, 3))),
                weights = I(c(1, 1)))
  out <- capture.output(
    contrib <- wave_contribution(dl, micro, list(wave = "W", wave_order = 2024)))
  keys <- vapply(contrib$questions, function(q) q$match_key, character(1))
  expect_equal(keys, c("overall rating", "overall rating#1"))
  expect_equal(as.numeric(contrib$questions[[1]]$scores), c(6, 8))   # Q1's own
  expect_equal(as.numeric(contrib$questions[[2]]$scores), c(1, 3))   # Q2's own
})

context("tracking_island: stale-wave dedupe")

test_that("build_tracking_island drops a stale prior carrying the current wave's label", {
  mk <- function(name, ord, vals) {
    micro <- list(n = 2, scores = list(Q1 = I(vals)), weights = I(c(1, 1)))
    dl <- list(questions = list(list(code = "Q1", title = "Overall rating", type = "scale")))
    wave_contribution(dl, micro, list(wave = name, wave_order = ord))
  }
  current <- mk("Wave 2026", 2026, c(6, 8))
  stale   <- mk("Wave 2026", 2026, c(1, 2))    # earlier run of the SAME wave
  real    <- mk("Wave 2025", 2025, c(5, 7))
  out <- capture.output(island <- build_tracking_island(current, list(real, stale)))
  labels <- vapply(island$waves, function(w) w$wave, character(1))
  expect_equal(labels, c("Wave 2025", "Wave 2026"))                  # stale dropped
  expect_true(isTRUE(island$waves[[2]]$current))
  expect_equal(as.numeric(island$waves[[2]]$questions[[1]]$scores), c(6, 8))
  expect_true(any(grepl("stale prior contribution", out)))
})

test_that("read_wave_contributions keeps only the NEWEST sidecar per wave label", {
  d <- tempfile("waves_"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  wj <- function(label, val) sprintf(
    '{"wave":"%s","year":2025,"segments":[],"questions":[{"code":"Q1","match_key":"m","title":"M","base":1,"score_type":"mean","scores":[%d]}]}',
    label, val)
  old_f <- file.path(d, "proj_old_wave.json")
  new_f <- file.path(d, "proj_new_wave.json")
  other <- file.path(d, "proj_2024_wave.json")
  writeLines(wj("Wave 2025", 1), old_f)
  writeLines(wj("Wave 2025", 2), new_f)
  writeLines(sub('"year":2025', '"year":2024', wj("Wave 2024", 9)), other)
  Sys.setFileTime(old_f, Sys.time() - 3600)          # the stale one is older
  out <- capture.output(res <- read_wave_contributions(d))
  labels <- vapply(res, function(c) as.character(c$wave), character(1))
  expect_setequal(labels, c("Wave 2025", "Wave 2024"))
  kept <- Find(function(c) identical(as.character(c$wave), "Wave 2025"), res)
  expect_equal(kept$questions[[1]]$scores[[1]], 2)   # newest file won
  expect_true(any(grepl("stale duplicate", out)))
})
