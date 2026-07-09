# ==============================================================================
# TABS MODULE — AGGREGATE-WAVE BRIDGE TESTS (v2 aggregate tracking, stage 1)
# ==============================================================================
#
# Locks aggregate_wave_contributions() / write_aggregate_wave_sidecars()
# (tracking_aggregate_bridge.R): a pre-computed long values table -> the v2
# wave-island PRIOR-wave shapes the renderer (assets/js/22w_waves.js) reads,
# mirroring test_tracking_segment_bridge.R. The value-only twin of the segment
# bridge, so it must emit the same island contract with honest significance:
#   mean  -> stats.index (+ .mean), + .sd ONLY when recorded
#   nps   -> stats.nps (never an sd/index -> "no test")
#   prop  -> rows[norm(category)].pct, + .n ONLY when a base is known
#
# Run with:
#   Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/test_tracking_aggregate_bridge.R")'
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
source(file.path(turas_root, "modules/tabs/lib/tracking_island.R"))            # tracking_norm, %||%, island helpers
source(file.path(turas_root, "modules/tabs/lib/tracking_aggregate_bridge.R"))

# ---- fixture: a mean + an NPS + a proportion, across two waves. The 2011 wave
# has NO base and NO sd (untested history); the 2025 wave carries a real base,
# and only the mean carries an sd. metric_id == the canonical QuestionCode.
values <- data.frame(
  metric_id   = c("HQ1", "HQ1", "HQ2", "HQ2", "HQ3", "HQ3"),
  wave        = c("2011", "2025", "2011", "2025", "2011", "2025"),
  metric_type = c("mean", "mean", "nps",  "nps",  "proportion", "proportion"),
  value       = c(8.8,    9.1,    60,     65,     40,           45),
  base        = c(NA,     190,    NA,     190,    NA,           200),
  sd          = c(NA,     1.4,    NA,     NA,     NA,           NA),
  stringsAsFactors = FALSE)

mapping <- data.frame(
  QuestionCode  = c("HQ1", "HQ2", "HQ3"),
  QuestionText  = c("Overall rating", "Recommend", "Requested signage"),
  TrackingSpecs = c("mean", "nps_score", "category:Yes"),
  stringsAsFactors = FALSE)

waves_meta <- list(list(id = "2011", label = "2011", year = 2011),
                   list(id = "2025", label = "2025", year = 2025))

res <- aggregate_wave_contributions(values, mapping, waves_meta)

test_that("one prior-wave contribution per wave, oldest first, current = FALSE, Total-only", {
  expect_equal(length(res), 2)
  expect_equal(res[[1]]$wave, "2011")
  expect_equal(res[[1]]$year, 2011)
  expect_false(res[[1]]$current)
  expect_equal(res[[2]]$wave, "2025")
  expect_equal(length(res[[1]]$segments), 0)              # aggregate history has no breakouts
})

test_that("mean carries index + mean, and sd ONLY when recorded (honest)", {
  q25 <- res[[2]]$questions[[1]]                          # HQ1 mean, 2025
  expect_equal(q25$match_key, "hq1")                      # tracking_norm(metric_id)
  expect_equal(q25$title, "Overall rating")              # from the mapping
  expect_equal(q25$stats$index, 9.1)                     # renderer reads stats.index
  expect_equal(q25$stats$mean, 9.1)                      # mirror so a "Mean" label also resolves
  expect_equal(q25$stats$sd, 1.4)                        # recorded -> Welch test can run
  expect_equal(q25$base, 190)

  q11 <- res[[1]]$questions[[1]]                          # HQ1 mean, 2011
  expect_equal(q11$stats$index, 8.8)
  expect_null(q11$stats$sd)                               # blank sd -> plots untested
  expect_true(is.na(q11$base))                            # blank base -> serialises null
})

test_that("mean question carries exactly the locked island fields", {
  expect_setequal(names(res[[2]]$questions[[1]]),
                  c("match_key", "title", "base", "stats"))
})

test_that("NPS carries nps only — no sd, no index (net alone can't be tested)", {
  q2 <- res[[2]]$questions[[2]]                           # HQ2 nps, 2025
  expect_equal(q2$stats$nps, 65)
  expect_equal(q2$match_key, "hq2")
  expect_null(q2$stats$sd)
  expect_null(q2$stats$index)
  expect_null(q2$stats$mean)
  expect_setequal(names(q2), c("match_key", "title", "base", "stats"))
})

test_that("proportion emits a rows[norm(category)] row; n only when base known", {
  q3 <- res[[2]]$questions[[3]]                           # HQ3 proportion, 2025
  expect_equal(q3$match_key, "hq3")
  expect_null(q3$stats)                                   # proportions carry rows, not stats
  expect_setequal(names(q3), c("match_key", "title", "base", "rows"))
  expect_equal(q3$rows[["yes"]]$pct, 45)                  # category:Yes -> tracking_norm("Yes")
  expect_equal(q3$rows[["yes"]]$n, round(45 / 100 * 200)) # 90
  expect_equal(q3$base, 200)

  q3_11 <- res[[1]]$questions[[3]]                        # HQ3 proportion, 2011 (no base)
  expect_equal(q3_11$rows[["yes"]]$pct, 40)
  expect_null(q3_11$rows[["yes"]]$n)                      # blank base -> no count -> no test
})

test_that("category:Value=Label uses the Value (the crosstab row text), not the label", {
  v <- data.frame(metric_id = "HQ7", wave = "2011", metric_type = "proportion",
                  value = 33, base = 100, sd = NA, stringsAsFactors = FALSE)
  m <- data.frame(QuestionCode = "HQ7", QuestionText = "Awareness",
                  TrackingSpecs = "category:Yes=Aware", stringsAsFactors = FALSE)
  out <- aggregate_wave_contributions(v, m)
  expect_equal(names(out[[1]]$questions[[1]]$rows), "yes")   # keyed on "Yes", not "Aware"
})

test_that("a proportion with no resolvable category is SKIPPED with a warning, never mis-keyed", {
  v <- data.frame(metric_id = "HQ9", wave = "2011", metric_type = "proportion",
                  value = 50, base = 100, sd = NA, stringsAsFactors = FALSE)
  m <- data.frame(QuestionCode = "HQ9", QuestionText = "No category",
                  TrackingSpecs = "mean", stringsAsFactors = FALSE)  # no category: spec
  logged <- capture.output(out <- aggregate_wave_contributions(v, m))
  expect_equal(length(out), 0)                                        # nothing emitted
  expect_true(any(grepl("no TrackingSpecs category", logged)))
})

test_that("without a mapping: mean/nps emit (title = metric_id); proportions are skipped", {
  logged <- capture.output(res_nomap <- aggregate_wave_contributions(values, NULL, waves_meta))
  q <- res_nomap[[2]]$questions
  kinds <- vapply(q, function(x) if (!is.null(x$rows)) "prop" else "meanish", character(1))
  expect_false("prop" %in% kinds)                                     # proportion dropped (no category)
  expect_equal(res_nomap[[2]]$questions[[1]]$title, "HQ1")            # title falls back to metric_id
  expect_equal(res_nomap[[2]]$questions[[1]]$match_key, "hq1")        # match_key still aligns
  expect_true(any(grepl("no TrackingSpecs category", logged)))
})

test_that("waves_meta is auto-derived from the values table when omitted", {
  res_auto <- aggregate_wave_contributions(values, mapping)           # waves_meta = NULL
  expect_equal(length(res_auto), 2)
  expect_equal(res_auto[[1]]$year, 2011)                              # 4-digit year parsed from id
  expect_equal(res_auto[[1]]$wave, "2011")
  expect_equal(res_auto[[1]]$questions[[1]]$stats$index, 8.8)
})

test_that("degenerate / malformed inputs yield an empty list (no fabrication)", {
  expect_equal(length(aggregate_wave_contributions(data.frame())), 0)
  expect_equal(length(aggregate_wave_contributions(values[0, ], mapping, waves_meta)), 0)
  # a wave asked for that isn't in the values table just yields nothing
  expect_equal(length(aggregate_wave_contributions(
    values, mapping, list(list(id = "1999", label = "1999", year = 1999)))), 0)
  # missing a required column -> warn + empty (never a half-built contribution)
  bad <- values[, c("metric_id", "wave", "value")]                   # no metric_type
  logged <- capture.output(out <- aggregate_wave_contributions(bad, mapping, waves_meta))
  expect_equal(length(out), 0)
  expect_true(any(grepl("missing required column", logged)))
})

test_that("questions serialise as JSON objects, Total-only (no segment scaffolding)", {
  jm <- as.character(jsonlite::toJSON(res[[2]]$questions[[1]], auto_unbox = TRUE, na = "null"))
  expect_match(jm, '"stats":\\{"mean":9.1')
  expect_match(jm, '"index":9.1')
  expect_match(jm, '"sd":1.4')
  expect_false(grepl('"seg_stats"', jm))               # Total-only: none emitted
  expect_false(grepl('"bases"', jm))

  jp <- as.character(jsonlite::toJSON(res[[2]]$questions[[3]], auto_unbox = TRUE, na = "null"))
  expect_match(jp, '"rows":\\{"yes":\\{"pct":45')
  expect_match(jp, '"n":90')
  expect_false(grepl('"seg"', jp))                     # no per-segment block on the row
})

test_that("sidecars round-trip: write -> read_wave_contributions -> keys preserved", {
  tmp <- file.path(tempdir(), paste0("aggwave_", as.integer(length(res)), "_rt"))
  if (dir.exists(tmp)) unlink(tmp, recursive = TRUE)
  logged <- capture.output(paths <- write_aggregate_wave_sidecars(values, mapping, waves_meta, tmp))
  expect_equal(length(paths), 2)                       # one sidecar per wave
  expect_true(all(file.exists(paths)))

  priors <- read_wave_contributions(tmp)
  expect_equal(length(priors), 2)
  expect_true(all(vapply(priors, function(p) length(p$questions) > 0, logical(1))))
  allkeys <- unlist(lapply(priors, function(p)
    vapply(p$questions, function(q) as.character(q$match_key), character(1))))
  expect_true(all(c("hq1", "hq2", "hq3") %in% allkeys))
  unlink(tmp, recursive = TRUE)
})

test_that("a metric present in the values table but absent from the mapping still emits (no crash)", {
  # partial curation: history carries HQ1, but the mapping only lists other codes.
  v <- data.frame(metric_id = "HQ1", wave = "2011", metric_type = "mean",
                  value = 8.8, base = NA, sd = NA, stringsAsFactors = FALSE)
  m <- data.frame(QuestionCode = "HQZZ", QuestionText = "Other",
                  TrackingSpecs = "mean", stringsAsFactors = FALSE)
  out <- aggregate_wave_contributions(v, m)
  expect_equal(length(out), 1)
  expect_equal(out[[1]]$questions[[1]]$title, "HQ1")        # falls back to metric_id
  expect_equal(out[[1]]$questions[[1]]$match_key, "hq1")    # still aligns with the current wave
})

test_that("the 'proportions' plural metric_type is accepted (loader alias)", {
  v <- data.frame(metric_id = "HQ3", wave = "2011", metric_type = "proportions",
                  value = 40, base = 100, sd = NA, stringsAsFactors = FALSE)
  m <- data.frame(QuestionCode = "HQ3", QuestionText = "Signage",
                  TrackingSpecs = "category:Yes", stringsAsFactors = FALSE)
  out <- aggregate_wave_contributions(v, m)
  expect_equal(out[[1]]$questions[[1]]$rows[["yes"]]$pct, 40)
})

test_that("the real stage-2 -> stage-3 path: written sidecars (blank base -> null) re-assemble into a valid island", {
  # This is what actually happens live: sidecars are generated once, then read +
  # assembled by a later run. A blank base survives as JSON null (no fabricated
  # base), and the round-tripped priors must still serialise into a valid island.
  vv <- data.frame(metric_id = c("HQ1", "HQ3"), wave = c("2011", "2011"),
                   metric_type = c("mean", "proportion"), value = c(8.8, 40),
                   base = c(NA, NA), sd = c(NA, NA), stringsAsFactors = FALSE)
  mm <- data.frame(QuestionCode = c("HQ1", "HQ3"), QuestionText = c("Overall", "Signage"),
                   TrackingSpecs = c("mean", "category:Yes"), stringsAsFactors = FALSE)
  tmp <- file.path(tempdir(), "aggwave_rt_reserialize")
  if (dir.exists(tmp)) unlink(tmp, recursive = TRUE)
  invisible(capture.output(write_aggregate_wave_sidecars(vv, mm, NULL, tmp)))

  priors <- read_wave_contributions(tmp)
  expect_null(priors[[1]]$questions[[1]]$base)             # blank base round-trips as null, not a number
  current <- list(wave = "2026", year = 2026, current = TRUE, segments = list(),
                  questions = list(list(match_key = "hq1", title = "Overall", base = 100,
                    score_type = "mean", scores = as.list(c(9, 9, 8, 10, 9)))))
  island <- build_tracking_island(current, priors)
  expect_equal(length(island$waves), 2)                    # 1 prior + current
  expect_true(jsonlite::validate(serialize_tracking_island(island)))
  unlink(tmp, recursive = TRUE)
})

test_that("assembles + serialises into a valid island alongside a live current wave", {
  # the current 2026 wave stays a live microdata contribution (scores); the
  # aggregate bridge supplies the 2011 + 2025 priors. They align by match_key.
  current <- list(wave = "2026", year = 2026, current = TRUE, segments = list(),
                  questions = list(list(match_key = "hq1", title = "Overall rating",
                    base = 120, score_type = "mean",
                    scores = as.list(c(9, 9, 8, 10, 9)))))
  island <- build_tracking_island(current, res)
  expect_equal(island$schema_version, 1L)
  expect_equal(length(island$waves), 3)                       # 2 priors + current
  years <- vapply(island$waves, function(w) as.numeric(w$year), numeric(1))
  expect_equal(years, sort(years))                            # oldest-first
  expect_true(island$waves[[length(island$waves)]]$current)   # current wave last

  j <- serialize_tracking_island(island)
  expect_true(jsonlite::validate(j))
  expect_match(j, '"stats":\\{"mean":9.1')                    # prior mean survives
  expect_match(j, '"index":8.8')                              # untested historical mean carries index
  expect_match(j, '"rows":\\{"yes"')                          # prior proportion survives
})
