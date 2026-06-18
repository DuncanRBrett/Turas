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
    x
  }
  list(metric_type = mtype, question_text = text,
       wave_results = list(W1 = wr(w1[[1]], w1[[2]]), W2 = wr(w2[[1]], w2[[2]])))
}

trend_results <- list(
  Q1 = list(
    "Total"               = make_seg("Overall satisfaction", "mean", list(7.0, 180), list(7.3, 190)),
    "Region_Western Cape" = make_seg("Overall satisfaction", "mean", list(6.8, 85),  list(7.1, 88)),
    "Region_Gauteng"      = make_seg("Overall satisfaction", "mean", list(7.2, 75),  list(7.5, 78))),
  Q2 = list(
    "Total"               = make_seg("Recommend", "nps", list(30, 180), list(35, 190), field = "nps"),
    "Region_Western Cape" = make_seg("Recommend", "nps", list(25, 85),  list(28, 88),  field = "nps"),
    "Region_Gauteng"      = make_seg("Recommend", "nps", list(36, 75),  list(42, 78),  field = "nps")))

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
})

test_that("NPS question carries nps under stats/seg_stats (W2, Q2)", {
  q2 <- res[[2]]$questions[[2]]
  expect_equal(q2$stats$nps, 35)
  expect_equal(q2$seg_stats[["gauteng"]]$nps, 42)
  expect_equal(q2$match_key, "recommend")
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
  expect_match(j, '"stats":\\{"mean":7\\}')
  expect_match(j, '"seg_stats":\\{')
  expect_match(j, '"bases":\\{')
})

test_that("degenerate input yields an empty contribution list", {
  expect_equal(length(tracker_segment_contributions(list(), segments_meta, waves_meta)), 0)
  expect_equal(length(tracker_segment_contributions(trend_results, segments_meta, list())), 0)
})
