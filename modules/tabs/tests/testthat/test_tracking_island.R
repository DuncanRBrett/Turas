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
  expect_equal(length(contrib$questions), 2)        # Q1, Q2, not Q3
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

# An ALLOCATION question carries its values under micro$series (one per item
# row), never under micro$scores, because it has k means and no single
# per-respondent score. wave_contribution reads scores only, so it contributes
# nothing to a wave. Per-item wave tracking is a follow-up and needs a per-item
# key in Question_Mapping; until then a metric silently keyed to item 1 would be
# worse than no metric at all.
test_that("an allocation question contributes no wave metric", {
  dl <- list(questions = list(
    list(code = "WALLET", title = "Share of wallet", type = "single",
         rows = list(list(kind = "mean", label = "Bank", mstat = "mean"),
                     list(kind = "mean", label = "Retailer", mstat = "mean")))))
  micro <- list(
    n = 3,
    scores = list(),
    series = list(WALLET = list("0" = I(c(80, 20, 50)), "1" = I(c(20, 80, 50)))),
    weights = I(c(1, 1, 1)))
  expect_null(wave_contribution(dl, micro, list(wave = "W", wave_order = 2024)))

  # Alongside a question that DOES carry scores, only that one is tracked: the
  # allocation is skipped, not the whole contribution.
  dl2 <- list(questions = c(dl$questions, list(
    list(code = "Q1", title = "Overall rating", type = "scale"))))
  micro2 <- micro
  micro2$scores <- list(Q1 = I(c(6, 8, 7)))
  contrib <- wave_contribution(dl2, micro2, list(wave = "W", wave_order = 2024))
  expect_equal(length(contrib$questions), 1L)
  expect_equal(contrib$questions[[1]]$code, "Q1")
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
  expect_true(any(grepl("share the normalised title", out)))
  expect_true(any(grepl("question_mapping", out)))    # the reliable way to track them
})

test_that("duplicate-title keys survive a reorder. They follow the CODE (M14)", {
  # The suffix used to come from position in the data layer, so moving two
  # same-titled questions past each other handed each the other's key, and with
  # it the other's history. Same three questions, reordered: same keys.
  mk <- function(...) list(questions = list(...))
  q <- function(code) list(code = code, title = "Overall rating", type = "scale")
  keys_of <- function(dl) {
    m <- suppressWarnings(capture.output(res <- tracking_metrics(dl)))
    stats::setNames(vapply(res, function(x) x$key, character(1)),
                    vapply(res, function(x) x$code, character(1)))
  }
  a <- keys_of(mk(q("Q1"), q("Q2"), q("Q3")))
  b <- keys_of(mk(q("Q3"), q("Q1"), q("Q2")))          # same questions, reordered
  expect_equal(a[["Q1"]], b[["Q1"]])
  expect_equal(a[["Q2"]], b[["Q2"]])
  expect_equal(a[["Q3"]], b[["Q3"]])
  expect_equal(unname(a[["Q1"]]), "overall rating")    # lowest code keeps the bare key
  expect_equal(unname(a[["Q3"]]), "overall rating#2")
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

test_that("the sidecar dedupe follows the recorded build time, not the file date (M14)", {
  # A stale backup copied into waves_source gets a FRESH mtime, so ordering on
  # mtime handed the copy the win over the genuine newer run. The build stamp
  # travels inside the file, so a copy carries its original (older) stamp.
  dir <- file.path(tempdir(), paste0("m14_dedupe_", as.integer(runif(1, 1, 1e6))))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  mk <- function(vals) {
    micro <- list(n = 2, scores = list(Q1 = I(vals)), weights = I(c(1, 1)))
    dl <- list(questions = list(list(code = "Q1", title = "Overall rating", type = "scale")))
    wave_contribution(dl, micro, list(wave = "Wave 2025", wave_order = 2025))
  }
  genuine <- mk(c(6, 8)); genuine$built <- "2026-08-05T09:00:00"
  stale   <- mk(c(1, 2)); stale$built   <- "2024-01-01T09:00:00"
  invisible(capture.output({
    write_wave_contribution(genuine, file.path(dir, "genuine_wave.json"))
    Sys.sleep(1.1)                                    # the COPY is written last
    write_wave_contribution(stale, file.path(dir, "stale_copy_wave.json"))
  }))
  mt <- file.mtime(c(file.path(dir, "genuine_wave.json"), file.path(dir, "stale_copy_wave.json")))
  expect_true(mt[2] > mt[1])                          # the stale file IS the newer file
  out <- capture.output(got <- read_wave_contributions(dir))
  expect_equal(length(got), 1)
  expect_equal(as.numeric(got[[1]]$questions[[1]]$scores), c(6, 8))   # genuine kept
  expect_true(any(grepl("recorded build time", out)))
})

test_that("write_wave_contribution stamps a sidecar that has no build time", {
  dir <- file.path(tempdir(), paste0("m14_stamp_", as.integer(runif(1, 1, 1e6))))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  micro <- list(n = 2, scores = list(Q1 = I(c(6, 8))), weights = I(c(1, 1)))
  dl <- list(questions = list(list(code = "Q1", title = "Overall rating", type = "scale")))
  contrib <- wave_contribution(dl, micro, list(wave = "W", wave_order = 2025))
  expect_null(contrib$built)                          # the builder stays deterministic
  p <- file.path(dir, "w_wave.json")
  invisible(capture.output(write_wave_contribution(contrib, p)))
  got <- jsonlite::read_json(p, simplifyVector = FALSE)
  expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$", as.character(got$built)))
})

test_that("an unstamped sidecar still dedupes, and the note says which rule ran (M14)", {
  dir <- file.path(tempdir(), paste0("m14_legacy_", as.integer(runif(1, 1, 1e6))))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  legacy <- function(vals, path) {
    writeLines(jsonlite::toJSON(list(wave = "Wave 2025", year = 2025, segments = list(),
      questions = list(list(code = "Q1", match_key = "overall rating", title = "x",
                            base = 2, score_type = "mean", scores = as.list(vals)))),
      auto_unbox = TRUE), path)
  }
  legacy(c(1, 2), file.path(dir, "old_wave.json"))
  Sys.sleep(1.1)
  legacy(c(6, 8), file.path(dir, "new_wave.json"))
  out <- capture.output(got <- read_wave_contributions(dir))
  expect_equal(length(got), 1)
  expect_equal(as.numeric(got[[1]]$questions[[1]]$scores), c(6, 8))   # newest file wins
  expect_true(any(grepl("file date, which a copy resets", out)))
})

test_that("two wave columns matching equally well is a warning, not a silent pick (M14)", {
  dl <- list(questions = list(list(code = "Q1", title = "A", type = "scale"),
                              list(code = "Q2", title = "B", type = "scale")))
  mapping <- data.frame(QuestionCode = c("K1", "K2"), QuestionText = c("A", "B"),
                        TrackingSpecs = c("", ""),
                        Wave25 = c("Q1", "Q2"), Wave26 = c("Q1", "Q2"),
                        stringsAsFactors = FALSE)
  out <- capture.output(wc <- detect_wave_column(mapping, dl))
  expect_equal(wc, "Wave25")                          # leftmost, as before
  expect_true(any(grepl("ambiguous wave column", out)))
  expect_true(any(grepl("Wave25, Wave26", out)))
})

test_that("an unambiguous wave column resolves quietly", {
  dl <- list(questions = list(list(code = "Q1", title = "A", type = "scale")))
  mapping <- data.frame(QuestionCode = "K1", QuestionText = "A", TrackingSpecs = "",
                        Wave25 = "Q1", Wave26 = "QX", stringsAsFactors = FALSE)
  out <- capture.output(wc <- detect_wave_column(mapping, dl))
  expect_equal(wc, "Wave25")
  expect_false(any(grepl("WARNING", out)))
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

# ==============================================================================
# 6. pairing report. An unmatched tracker must be LOUD, not silently zero
# ==============================================================================

context("tracking_island: pairing report")

# A wave keyed by title (no Question_Mapping) against history keyed by canonical
# code (built with one): the CCPB W2026 failure. Every trend comes out empty and
# the tab would render "0 significant increases / 0 decreases / 0 stable".
ti_contrib <- function(wave, year, keys) list(
  wave = wave, year = year, segments = list(),
  questions = lapply(keys, function(k) list(
    code = toupper(k), match_key = k, title = k, base = 3,
    score_type = "mean", scores = list(6, 7, 8))))

test_that("tracking_wave_keys reads match_key and falls back to title_norm", {
  w <- list(questions = list(list(match_key = "q02"), list(title_norm = "ease of ordering"),
                             list(match_key = ""), list()))
  expect_equal(tracking_wave_keys(w), c("q02", "ease of ordering"))
  expect_equal(tracking_wave_keys(list(questions = list())), character(0))
})

test_that("a total key mismatch warns loudly and names both key shapes", {
  current <- ti_contrib("W2026", 2026, c("please rate ccpb overall", "the ease of placing orders"))
  priors <- list(ti_contrib("2024", 2024, c("q78", "q02")),
                 ti_contrib("2025", 2025, c("q78", "q02")))
  out <- capture.output(res <- tracking_report_pairing(current, priors))
  expect_equal(res$matched, 0)
  expect_equal(res$current, 2)
  expect_equal(res$priors, 2)
  expect_true(any(grepl("no metric matched history", out)))
  expect_true(any(grepl("please rate ccpb overall", out)))   # this wave's shape
  expect_true(any(grepl("q78", out)))                        # history's shape
  expect_true(any(grepl("question_mapping", out)))           # the actionable fix
})

test_that("build_tracking_island raises the mismatch warning on assembly", {
  out <- capture.output(island <- build_tracking_island(
    ti_contrib("W2026", 2026, c("please rate ccpb overall")),
    list(ti_contrib("2025", 2025, c("q78")))))
  expect_equal(length(island$waves), 2)          # island still builds
  expect_true(any(grepl("no metric matched history", out)))
})

test_that("a partial mismatch notes the count instead of crying wolf", {
  out <- capture.output(res <- tracking_report_pairing(
    ti_contrib("W2026", 2026, c("q78", "q02", "q99")),
    list(ti_contrib("2025", 2025, c("q78", "q02")))))
  expect_equal(res$matched, 2)
  expect_equal(res$unmatched, 1)
  expect_true(any(grepl("2 of 3 metrics matched", out)))
  expect_false(any(grepl("no metric matched history", out)))
})

test_that("a full match says so quietly and never warns", {
  out <- capture.output(res <- tracking_report_pairing(
    ti_contrib("W2026", 2026, c("q78", "q02")),
    list(ti_contrib("2025", 2025, c("q78", "q02")))))
  expect_equal(res$matched, 2)
  expect_equal(res$unmatched, 0)
  expect_true(any(grepl("all 2 metrics matched", out)))
  expect_false(any(grepl("WARNING", out)))
})

test_that("a first wave (no history) is not a mismatch", {
  out <- capture.output(res <- tracking_report_pairing(
    ti_contrib("W2026", 2026, c("q78")), list()))
  expect_equal(res$matched, 0)
  expect_equal(res$priors, 0)
  expect_equal(length(out), 0)                   # nothing to say, says nothing
})


# ---------------------------------------------------------------------------
# I24. Option-level pairing. A proportion trend pairs row by row on the
# normalised option label alone (22w_waves.js rowValue), and contributes no
# mean/NPS metric, so the question-level report above never looked at it: a
# renamed option silently truncated that trend and read as "no movement".
# ---------------------------------------------------------------------------

# A data layer carrying one proportion question with the given option labels.
ti_dl <- function(code, title, labels, kinds = NULL) {
  if (is.null(kinds)) kinds <- rep("category", length(labels))
  list(questions = list(list(
    code = code, title = title, type = "single",
    rows = c(lapply(seq_along(labels), function(i) {
      list(kind = kinds[i], label = labels[i])
    }), list(list(kind = "mean", label = "Mean"))))))
}

# A prior wave whose question publishes those option rows.
ti_prior_rows <- function(wave, year, key, labels) {
  rows <- stats::setNames(lapply(labels, function(l) list(pct = 50)),
                          tracking_norm(labels))
  list(wave = wave, year = year, segments = list(),
       questions = list(list(match_key = key, title = key, base = 400, rows = rows)))
}

test_that("tracking_option_labels reads category and NET rows, never the mean", {
  dl <- ti_dl("Q1", "Satisfaction", c("Very satisfied", "Satisfied", "Top 2 Box"),
              kinds = c("category", "category", "net"))
  expect_equal(tracking_option_labels(dl$questions[[1]]),
               c("very satisfied", "satisfied", "top 2 box"))
  expect_equal(tracking_option_labels(list(rows = list())), character(0))
})

test_that("a renamed option is NAMED, not silently dropped from the trend", {
  dl <- ti_dl("Q1", "Satisfaction", c("Extremely satisfied", "Satisfied", "Dissatisfied"))
  priors <- list(ti_prior_rows("2025", 2025, "satisfaction",
                               c("Very satisfied", "Satisfied", "Dissatisfied")))
  out <- capture.output(res <- tracking_report_option_pairing(dl, priors))
  expect_equal(res$checked, 3)
  expect_equal(res$matched, 2)
  expect_equal(res$unmatched, 1)
  expect_true(any(grepl("1 of 3 option", out)))
  expect_true(any(grepl("extremely satisfied", out)))   # the label that broke
  expect_false(any(grepl("WARNING", out)))              # partial: a note, not a warning
})

test_that("every option unmatched warns loudly and says what to do", {
  dl <- ti_dl("Q1", "Satisfaction", c("Strongly agree", "Agree"))
  priors <- list(ti_prior_rows("2025", 2025, "satisfaction", c("Top box", "Second box")))
  out <- capture.output(res <- tracking_report_option_pairing(dl, priors))
  expect_equal(res$matched, 0)
  expect_true(any(grepl("no option row matched history", out)))
  expect_true(any(grepl("normalised label", out)))
})

test_that("a full option match says so quietly", {
  dl <- ti_dl("Q1", "Satisfaction", c("Agree", "Disagree"))
  priors <- list(ti_prior_rows("2025", 2025, "satisfaction", c("Agree", "Disagree")))
  out <- capture.output(res <- tracking_report_option_pairing(dl, priors))
  expect_equal(res$unmatched, 0)
  expect_true(any(grepl("all 2 tracked option row", out)))
})

test_that("a mean-only history reports nothing about options", {
  dl <- ti_dl("Q78", "q78", c("Agree", "Disagree"))
  out <- capture.output(res <- tracking_report_option_pairing(
    dl, list(ti_contrib("2025", 2025, c("q78")))))
  expect_equal(res$checked, 0)
  expect_equal(length(out), 0)                   # no rows in history -> silent
})

test_that("the option check runs even when this wave contributes no metric", {
  # A proportion-only tracker: nothing carries microdata scores, so the
  # question-level report has an empty current contribution and says nothing,
  # exactly the case that had no check at all before.
  dl <- ti_dl("Q1", "Satisfaction", c("Extremely satisfied", "Satisfied"))
  priors <- list(ti_prior_rows("2025", 2025, "satisfaction",
                               c("Very satisfied", "Satisfied")))
  out <- capture.output(res <- tracking_report_pairing(
    list(wave = "W2026", year = 2026, questions = list()), priors, dl))
  expect_equal(res$options$unmatched, 1)
  expect_true(any(grepl("extremely satisfied", out)))
})

test_that("build_tracking_island forwards the data layer to the option check", {
  dl <- ti_dl("Q78", "q78", c("Renamed option", "Agree"))
  priors <- list(ti_prior_rows("2025", 2025, "q78", c("Agree", "Disagree")))
  out <- capture.output(island <- build_tracking_island(
    ti_contrib("W2026", 2026, c("q78")), priors, dl))
  expect_equal(length(island$waves), 2)          # island still builds
  expect_true(any(grepl("renamed option", out)))
})

# ==============================================================================
# 8. PUBLISHED (no-microdata) current wave. The confidentiality ship
# ==============================================================================
#
# html_report_v2_microdata = FALSE ships no per-respondent records. The Tracking
# tab used to disappear with them, which put anonymity and a trend line in
# competition. published_wave_contribution() builds the current wave from the
# published figures instead: same metric set, same cross-wave keys, no scores.

context("tracking_island: published (no-microdata) current wave")

pw_dl <- function() list(questions = list(
  list(code = "Q1", title = "Overall rating", type = "scale",
       rows = list(list(kind = "category", label = "Good"),
                   list(kind = "mean", label = "Mean")),
       bases = list(list(n = 120), list(n = 60))),
  list(code = "Q2", title = "Recommend (NPS)", type = "nps",
       rows = list(list(kind = "mean", label = "NPS")),
       bases = list(list(n = 118))),
  list(code = "Q3", title = "No mean here", type = "single",
       rows = list(list(kind = "category", label = "Yes")),
       bases = list(list(n = 120)))))

pw_micro <- function() list(
  n = 3,
  scores = list(Q1 = I(c(6, 8, 7)), Q2 = I(c(100, 100, -100))),
  weights = I(c(1, 1, 1)))

pw_cfg <- function() list(wave = "SACS 2026", wave_order = 2026)

test_that("the published contribution carries NO per-respondent fields", {
  contrib <- published_wave_contribution(pw_dl(), pw_cfg())
  expect_equal(contrib$wave, "SACS 2026")
  expect_equal(contrib$year, 2026)
  for (q in contrib$questions) {
    expect_null(q$scores)
    expect_null(q$weights)
  }
  # And nothing per-respondent survives serialisation either.
  json <- serialize_tracking_island(build_tracking_island(contrib, list()))
  expect_false(grepl("scores", json, fixed = TRUE))
  expect_false(grepl("weights", json, fixed = TRUE))
})

test_that("it tracks the SAME metrics, with the same keys, as the microdata build", {
  # The whole point: the confidential copy and the analyst's working copy of the
  # same wave must show the same trend, or the two files disagree.
  dl <- pw_dl()
  micro_contrib <- wave_contribution(dl, pw_micro(), pw_cfg())
  pub_contrib   <- published_wave_contribution(dl, pw_cfg())

  field <- function(contrib, nm) vapply(contrib$questions, function(q) as.character(q[[nm]]), character(1))
  expect_equal(field(pub_contrib, "code"), field(micro_contrib, "code"))
  expect_equal(field(pub_contrib, "match_key"), field(micro_contrib, "match_key"))
  expect_equal(field(pub_contrib, "score_type"), field(micro_contrib, "score_type"))
})

test_that("a question that publishes no mean is not tracked", {
  contrib <- published_wave_contribution(pw_dl(), pw_cfg())
  expect_false("Q3" %in% vapply(contrib$questions, function(q) q$code, character(1)))
  expect_equal(length(contrib$questions), 2)
})

test_that("the published base is the Total column's, not a banner column's", {
  contrib <- published_wave_contribution(pw_dl(), pw_cfg())
  q1 <- contrib$questions[[1]]
  expect_equal(q1$code, "Q1")
  expect_equal(q1$base, 120)          # bases[[1]], not the 60 in bases[[2]]
})

test_that("no question publishes a mean -> NULL (no Tracking tab, as before)", {
  dl <- list(questions = list(
    list(code = "Q3", title = "No mean here", type = "single",
         rows = list(list(kind = "category", label = "Yes")),
         bases = list(list(n = 120)))))
  expect_null(published_wave_contribution(dl, pw_cfg()))
  # A data layer whose questions carry no rows at all (older shape) is also NULL
  # rather than a contribution of metrics that publish nothing.
  expect_null(published_wave_contribution(ti_data_layer(), pw_cfg()))
})

test_that("a question mapping still curates the metric set and the keys", {
  mapping <- data.frame(
    QuestionCode = c("Track_01", "Track_02"),
    QuestionText = c("Overall rating", "Recommend"),
    TrackingSpecs = c("mean", "nps_score"),
    Wave2026 = c("Q1", "Q2"),
    stringsAsFactors = FALSE)
  contrib <- published_wave_contribution(pw_dl(), pw_cfg(), mapping)
  expect_equal(vapply(contrib$questions, function(q) q$match_key, character(1)),
               c("track01", "track02"))
  expect_equal(vapply(contrib$questions, function(q) q$score_type, character(1)),
               c("mean", "nps"))
})

test_that("a published current wave assembles and is flagged current", {
  priors <- list(ti_contrib("SACS 2025", 2025, c("overall rating")))
  island <- build_tracking_island(published_wave_contribution(pw_dl(), pw_cfg()),
                                  priors)
  expect_equal(length(island$waves), 2)
  expect_false(isTRUE(island$waves[[1]]$current))   # 2025 first
  expect_true(isTRUE(island$waves[[2]]$current))    # 2026 current
})
