# ==============================================================================
# TABS MODULE — TRACKING SEGMENT BRIDGE TESTS (Phase 1b)
# ==============================================================================
#
# Verifies tracker_segment_contributions() serialises the classic tracker's
# per-segment trend output into the v2 wave-island prior-wave shape the renderer
# (assets/js/22w_waves.js) reads — the schema locked by the JS gate test
# "per-segment prior-wave trends" in prototypes/.../tests/run_tests_v2.mjs.
#
# Run with:
#   Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/test_tracking_segment_bridge.R")'
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
source(file.path(turas_root, "modules/tabs/lib/tracking_island.R"))        # tracking_norm, %||%
source(file.path(turas_root, "modules/tabs/lib/tracking_segment_bridge.R"))

# ---- fixtures: a 2-segment (Region) tracker output for a mean + an NPS question
make_seg <- function(text, mtype, w1, w2, field = "mean") {
  wr <- function(v, n) {
    x <- list(n_unweighted = n, available = TRUE)
    x[[field]] <- v
    if (identical(field, "mean")) x$sd <- 1.5   # tracker supplies SD for means
    x
  }
  list(metric_type = mtype, question_text = text,
       wave_results = list(W1 = wr(w1[[1]], w1[[2]]), W2 = wr(w2[[1]], w2[[2]])))
}

make_prop_seg <- function(text, w1, w2) {
  wr <- function(props, n) list(proportions = props, n_unweighted = n, available = TRUE)
  list(metric_type = "proportions", question_text = text,
       wave_results = list(W1 = wr(w1$props, w1$n), W2 = wr(w2$props, w2$n)))
}

trend_results <- list(
  Q1 = list(
    "Total"               = make_seg("Overall satisfaction", "mean", list(7.0, 180), list(7.3, 190)),
    "Region_Western Cape" = make_seg("Overall satisfaction", "mean", list(6.8, 85),  list(7.1, 88)),
    "Region_Gauteng"      = make_seg("Overall satisfaction", "mean", list(7.2, 75),  list(7.5, 78))),
  Q2 = list(
    "Total"               = make_seg("Recommend", "nps", list(30, 180), list(35, 190), field = "nps"),
    "Region_Western Cape" = make_seg("Recommend", "nps", list(25, 85),  list(28, 88),  field = "nps"),
    "Region_Gauteng"      = make_seg("Recommend", "nps", list(36, 75),  list(42, 78),  field = "nps")),
  Q3 = list(
    "Total"               = make_prop_seg("Channel used",
      list(props = c("Online" = 40, "In-store" = 60), n = 180),
      list(props = c("Online" = 45, "In-store" = 55), n = 190)),
    "Region_Western Cape" = make_prop_seg("Channel used",
      list(props = c("Online" = 50, "In-store" = 50), n = 85),
      list(props = c("Online" = 55, "In-store" = 45), n = 88)),
    "Region_Gauteng"      = make_prop_seg("Channel used",
      list(props = c("Online" = 35, "In-store" = 65), n = 75),
      list(props = c("Online" = 38, "In-store" = 62), n = 78))))

segments_meta <- list(
  "Total"               = list(is_total = TRUE),
  "Region_Western Cape" = list(value = "Western Cape", variable = "Region", is_total = FALSE),
  "Region_Gauteng"      = list(value = "Gauteng",      variable = "Region", is_total = FALSE))

waves_meta <- list(list(id = "W1", label = "Wave 1", year = 2024),
                   list(id = "W2", label = "Wave 2", year = 2025))

res <- tracker_segment_contributions(trend_results, segments_meta, waves_meta)

test_that("one prior-wave contribution per wave, current = FALSE", {
  expect_equal(length(res), 2)
  expect_equal(res[[1]]$wave, "Wave 1")
  expect_equal(res[[1]]$year, 2024)
  expect_false(res[[1]]$current)
})

test_that("Total + per-segment means and bases carried (W1, Q1)", {
  q <- res[[1]]$questions[[1]]
  expect_equal(q$match_key, "overall satisfaction")
  expect_equal(q$stats$mean, 7.0)
  expect_equal(q$base, 180)
  expect_equal(q$seg_stats[["western cape"]]$mean, 6.8)
  expect_equal(q$seg_stats[["gauteng"]]$mean, 7.2)
  expect_equal(q$bases[["western cape"]], 85)
  expect_equal(q$bases[["gauteng"]], 75)
  expect_equal(q$stats$sd, 1.5)                       # mean SD carried for the Welch test
  expect_equal(q$seg_stats[["western cape"]]$sd, 1.5)
  expect_equal(q$stats$index, 7.0)                    # also exposed as index ("Index"-labelled rows)
  expect_equal(q$seg_stats[["western cape"]]$index, 6.8)
})

test_that("NPS question carries nps under stats/seg_stats (W2, Q2)", {
  q2 <- res[[2]]$questions[[2]]
  expect_equal(q2$stats$nps, 35)
  expect_equal(q2$seg_stats[["gauteng"]]$nps, 42)
  expect_equal(q2$match_key, "recommend")
  expect_null(q2$stats$sd)                            # NPS carries no SD
})

test_that("segments list uses normalised column-label keys + group", {
  norms <- vapply(res[[1]]$segments, function(s) s$norm, character(1))
  expect_setequal(norms, c("western cape", "gauteng"))
  groups <- unique(vapply(res[[1]]$segments, function(s) s$group, character(1)))
  expect_equal(groups, "Region")
})

test_that("question carries exactly the locked island fields", {
  expect_setequal(names(res[[1]]$questions[[1]]),
                  c("match_key", "title", "base", "stats", "seg_stats", "bases"))
})

test_that("serialises stats/seg_stats/bases as JSON objects, not arrays", {
  j <- as.character(jsonlite::toJSON(res[[1]]$questions[[1]], auto_unbox = TRUE))
  expect_match(j, '"stats":\\{"mean":7')             # object, mean auto-unboxed (sd follows)
  expect_match(j, '"seg_stats":\\{')
  expect_match(j, '"bases":\\{')
})

test_that("degenerate input yields an empty contribution list", {
  expect_equal(length(tracker_segment_contributions(list(), segments_meta, waves_meta)), 0)
  expect_equal(length(tracker_segment_contributions(trend_results, segments_meta, list())), 0)
})

test_that("proportions question emits published-distribution rows (Total + per-segment)", {
  q3 <- res[[1]]$questions[[3]]                       # Q3, W1
  expect_equal(q3$match_key, "channel used")
  expect_null(q3$stats)                               # proportions carry rows, not stats
  expect_setequal(names(q3), c("match_key", "title", "base", "rows", "bases"))
  expect_equal(q3$rows[["online"]]$pct, 40)
  expect_equal(q3$rows[["instore"]]$pct, 60)          # tracking_norm("In-store") == "instore"
  expect_equal(q3$rows[["online"]]$n, round(40 / 100 * 180))
  expect_equal(q3$rows[["online"]]$seg[["western cape"]], 50)
  expect_equal(q3$rows[["online"]]$seg[["gauteng"]], 35)
  expect_equal(q3$bases[["western cape"]], 85)
})

test_that("proportion segment values are distinct in W2", {
  q3 <- res[[2]]$questions[[3]]
  expect_equal(q3$rows[["online"]]$pct, 45)
  expect_equal(q3$rows[["online"]]$seg[["western cape"]], 55)
})

test_that("proportion rows round-trip as JSON objects with a nested seg object", {
  j <- as.character(jsonlite::toJSON(res[[1]]$questions[[3]], auto_unbox = TRUE))
  expect_match(j, '"rows":\\{')
  expect_match(j, '"seg":\\{"western cape"')
})

test_that("Total-only tracker (no breakout segments) still emits valid Total contributions", {
  total_only <- list(Total = list(is_total = TRUE))     # config with no Banner breakouts
  out <- tracker_segment_contributions(trend_results, total_only, waves_meta)
  expect_equal(length(out), 2)
  expect_equal(length(out[[1]]$segments), 0)            # no segment list
  q <- out[[1]]$questions[[1]]                          # Q1 mean
  expect_equal(q$stats$mean, 7.0)
  expect_equal(q$base, 180)
  expect_equal(length(q$seg_stats), 0)                  # no per-segment block
  expect_equal(length(q$bases), 0)
  island <- build_tracking_island(
    list(wave = "W3", year = 2026, current = TRUE, segments = list(), questions = list()), out)
  expect_true(jsonlite::validate(serialize_tracking_island(island)))
})

test_that("bridge output assembles + serialises into a valid tracking island", {
  # the current wave stays a live tabs Total contribution (scores), as today;
  # the bridge supplies the per-segment PRIOR waves.
  current <- list(wave = "Wave 3", year = 2026, current = TRUE, segments = list(),
                  questions = list(list(match_key = "overall satisfaction",
                    title = "Overall satisfaction", base = 200,
                    scores = as.list(c(7, 8, 7, 6, 8)))))
  island <- build_tracking_island(current, res)
  expect_equal(island$schema_version, 1L)
  expect_equal(length(island$waves), 3)                       # 2 priors + current
  years <- vapply(island$waves, function(w) as.numeric(w$year), numeric(1))
  expect_equal(years, sort(years))                            # ordered oldest-first
  expect_true(island$waves[[length(island$waves)]]$current)   # current wave last

  j <- serialize_tracking_island(island)
  expect_true(jsonlite::validate(j))
  expect_match(j, '"seg_stats":\\{"western cape"')            # per-segment means survive
  expect_match(j, '"segments":\\[')                           # segment list is an array
  expect_match(j, '"rows":\\{"online"')                       # proportion rows survive
})
