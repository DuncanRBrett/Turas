# ==============================================================================
# TABS MODULE — SEGMENT TREND COMPUTE TESTS
# ==============================================================================
# compute_segment_trends() orchestrates the tracker's calculators over per-
# respondent wave data into the trend_results shape the bridge consumes. Mirrors
# the SACS worked example (renumbered metric columns, a banner dimension).
#
#   Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/test_tracking_segment_compute.R")'
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  th <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(th) && dir.exists(file.path(th, "modules"))) return(normalizePath(th, mustWork = FALSE))
  for (c in c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."),
              file.path(getwd(), "../../../.."))) {
    r <- tryCatch(normalizePath(c, mustWork = FALSE), error = function(e) "")
    if (nzchar(r) && dir.exists(file.path(r, "modules"))) return(r)
  }
  stop("Cannot detect TURAS project root.")
}
root <- detect_turas_root()
source(file.path(root, "modules/tracker/lib/statistical_core.R"))      # calculators
source(file.path(root, "modules/tabs/lib/tracking_island.R"))          # tracking_norm, %||%
source(file.path(root, "modules/tabs/lib/tracking_segment_compute.R")) # compute_segment_trends
source(file.path(root, "modules/tabs/lib/tracking_segment_bridge.R"))  # tracker_segment_contributions

# Two waves; the engagement metric is renumbered (Q1 -> Q5) like real SACS.
w2024 <- data.frame(
  Q1   = c(4, 5, 5, 3, 5, 5, 4),
  NPS  = c(10, 9, 8, 0, 9, 10, 7),
  Chan = c("Online", "Online", "In-store", "In-store", "Online", "In-store", "Online"),
  Camp = c("Cape Town", "Cape Town", "Durban", "Durban", "Cape Town", "Durban", "Cape Town"),
  stringsAsFactors = FALSE)
w2025 <- data.frame(
  Q5   = c(5, 4, 4, 5, 4),
  NPS  = c(9, 8, 10, 9, 6),
  Chan = c("Online", "In-store", "Online", "In-store", "In-store"),
  Camp = c("Cape Town", "Durban", "Cape Town", "Durban", "Durban"),
  stringsAsFactors = FALSE)

waves <- list(list(id = "2024", data = w2024), list(id = "2025", data = w2025))
metrics <- list(
  list(code = "ENG", title = "I know what is expected of me at work", type = "mean",
       cols = list("2024" = "Q1", "2025" = "Q5")),
  list(code = "REC", title = "Recommend", type = "nps",
       cols = list("2024" = "NPS", "2025" = "NPS")),
  list(code = "CH", title = "Channel used", type = "proportions",
       cols = list("2024" = "Chan", "2025" = "Chan")))
segment_dims <- list(list(label = "Campus", cols = list("2024" = "Camp", "2025" = "Camp")))

ct <- compute_segment_trends(waves, metrics, segment_dims)

test_that("segments enumerate Total + each banner value seen across waves", {
  expect_true(ct$segments_meta$Total$is_total)
  expect_setequal(names(ct$segments_meta), c("Total", "Campus_Cape Town", "Campus_Durban"))
  expect_equal(ct$segments_meta[["Campus_Cape Town"]]$value, "Cape Town")
  expect_null(ct$segments_meta[["Campus_Cape Town"]]$.cols)   # internal field stripped
})

test_that("mean metric: Total + per-segment means from the tracker calculator", {
  eng <- ct$trend_results$ENG
  expect_equal(eng$Total$metric_type, "mean")
  expect_equal(eng$Total$wave_results[["2024"]]$mean, mean(c(4, 5, 5, 3, 5, 5, 4)))
  expect_equal(eng$Total$wave_results[["2024"]]$n_unweighted, 7)
  expect_equal(eng[["Campus_Cape Town"]]$wave_results[["2024"]]$mean, mean(c(4, 5, 5, 4)))  # 4.5
  expect_equal(eng[["Campus_Durban"]]$wave_results[["2024"]]$mean, mean(c(5, 3, 5)))         # 13/3
  expect_equal(eng[["Campus_Cape Town"]]$wave_results[["2025"]]$mean, mean(c(5, 4)))         # 4.5
})

test_that("nps + proportions dispatch to their calculators", {
  expect_equal(ct$trend_results$REC$Total$metric_type, "nps")
  expect_true(!is.null(ct$trend_results$REC$Total$wave_results[["2024"]]$nps))
  ch <- ct$trend_results$CH$Total$wave_results[["2024"]]$proportions
  expect_equal(round(ch[["Online"]], 2), round(4 / 7 * 100, 2))
})

test_that("compute -> bridge -> island carries per-segment values", {
  waves_meta <- list(list(id = "2024", label = "Wave 2024", year = 2024),
                     list(id = "2025", label = "Wave 2025", year = 2025))
  priors <- tracker_segment_contributions(ct$trend_results, ct$segments_meta, waves_meta)
  expect_equal(length(priors), 2)
  eng_q <- Filter(function(q) q$match_key == tracking_norm(metrics[[1]]$title),
                  priors[[1]]$questions)[[1]]
  expect_equal(eng_q$stats$mean, mean(c(4, 5, 5, 3, 5, 5, 4)))
  expect_equal(eng_q$seg_stats[["cape town"]]$mean, 4.5)
  expect_equal(eng_q$bases[["cape town"]], 4)
  ch_q <- Filter(function(q) q$match_key == "channel used", priors[[1]]$questions)[[1]]
  expect_equal(ch_q$rows[["online"]]$seg[["cape town"]], 100)   # both CT 2024 rows are Online
})
