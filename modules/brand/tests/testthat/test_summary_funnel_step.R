# ==============================================================================
# BRAND MODULE TESTS: the Overview's funnel step agrees with the engine
# ==============================================================================
# "Opportunities to examine" names the largest step down in the funnel. The
# engine already finds that step: .biggest_drop_for_focal() in R/03_funnel.R,
# over calculate_conversions()'s output.
#
# The Overview does not read that answer. It derives the step in JavaScript
# from the mini-funnel block .brsum_funnel_minif() already writes into the
# JSON island, because reading the engine's answer would mean adding numbers
# to the island, and the Stage 2 reachability gate asserts the island's
# numeric content is unchanged.
#
# So the two methods have to be shown to agree. They do, under the default
# conversion metric, because both are the smallest successive-stage ratio of
# the same pct_weighted series. This test proves it on a series built here,
# rather than leaving the claim to be inferred from reading two files.
#
# The divergence, stated rather than left to be found: with
# funnel.conversion_metric set to "absolute_gap", the engine's biggest drop is
# the largest absolute fall in percentage points, which can be a different
# step. The Overview always reports the ratio, and says so in its own words
# ("which is N% of the stage before it"), so its sentence stays true either
# way; it is the engine's answer it may then differ from.
# ==============================================================================

library(testthat)

.sfs_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R")) ||
        file.exists(file.path(d, "CLAUDE.md"))) return(d)
    d <- dirname(d)
  }
  getwd()
}
ROOT_SFS <- .sfs_root()

shared_lib_sfs <- file.path(ROOT_SFS, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib_sfs, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT_SFS, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT_SFS, "modules", "brand", "R", "03_funnel.R"))
source(file.path(ROOT_SFS, "modules", "brand", "lib", "html_report", "panels",
                 "14_summary_panel.R"))


# The IPK fixture's focal brand, measured off a generated report on
# 6 September 2026: aware 92.4658%, prefer 66.895%, past 12 months 62.3288%,
# past 3 months 44.9772% of total respondents. Its largest step down is
# 44.9772 / 62.3288 = 0.7216117, which is what the engine reports.
.sfs_stages <- function() {
  stages <- c("aware", "consideration", "bought_long", "bought_target")
  vals <- list(
    FOC   = c(92.4658, 66.8950, 62.3288, 44.9772),
    OTHER = c(61.3546, 24.3379, 23.3333, 12.5266)
  )
  out <- do.call(rbind, lapply(names(vals), function(b) {
    data.frame(brand_code = b, stage_key = stages,
               pct_weighted = vals[[b]], pct_unweighted = vals[[b]],
               n_weighted = 438, n_unweighted = 438,
               stringsAsFactors = FALSE)
  }))
  out
}


# The Overview's own derivation, in R, line for line with
# biggestFunnelDrop() in js/brand_summary_panel.js: the smallest successive
# ratio of the mini-funnel block's per-brand vector, skipping any step whose
# preceding stage is zero or missing.
.sfs_overview_step <- function(block, brand_code) {
  vals <- block$brands[[brand_code]]
  keys <- block$stage_keys
  if (is.null(vals) || length(vals) < 2) return(NULL)
  worst <- NULL
  for (i in seq(2, length(vals))) {
    prev <- vals[i - 1]; cur <- vals[i]
    if (!is.finite(prev) || !is.finite(cur) || prev <= 0) next
    ratio <- cur / prev
    if (is.null(worst) || ratio < worst$ratio) {
      worst <- list(from = keys[i - 1], to = keys[i], ratio = unname(ratio))
    }
  }
  worst
}


test_that("the Overview's funnel step is the step the engine reports", {
  stage_df <- .sfs_stages()
  conv_df <- calculate_conversions(stage_df, method = "ratio")
  engine <- .biggest_drop_for_focal(conv_df, "FOC")
  expect_false(is.null(engine))

  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = list(n_unweighted = 438, n_weighted = 438)))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  expect_true(isTRUE(block$available))

  overview <- .sfs_overview_step(block, "FOC")
  expect_false(is.null(overview))

  expect_identical(overview$from, engine$from_stage)
  expect_identical(overview$to,   engine$to_stage)
  expect_equal(overview$ratio, engine$value, tolerance = 1e-9)

  # And the value itself, so a change to either method is visible here.
  # 44.9772 / 62.3288 = 0.7216118. The engine printed 0.7216117 on the
  # fixture run because its stage percentages carry more decimals than the
  # four this test hard-codes; the two agree to six places.
  expect_equal(overview$ratio, 0.721612, tolerance = 1e-6)
  expect_identical(engine$to_stage, "bought_target")
})


test_that("they still agree when the largest fall is at another step", {
  stage_df <- .sfs_stages()
  # Move the largest proportional fall to aware -> consideration.
  stage_df$pct_weighted[stage_df$brand_code == "FOC"] <-
    c(90, 30, 27, 24)
  stage_df$pct_unweighted <- stage_df$pct_weighted

  conv_df <- calculate_conversions(stage_df, method = "ratio")
  engine <- .biggest_drop_for_focal(conv_df, "FOC")

  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = list(n_unweighted = 438, n_weighted = 438)))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  overview <- .sfs_overview_step(block, "FOC")

  expect_identical(overview$from, engine$from_stage)
  expect_identical(overview$to,   engine$to_stage)
  expect_identical(engine$to_stage, "consideration")
  expect_equal(overview$ratio, engine$value, tolerance = 1e-9)
})


test_that("a zero stage is skipped rather than reported as a total fall", {
  stage_df <- .sfs_stages()
  stage_df$pct_weighted[stage_df$brand_code == "FOC"] <- c(50, 0, 0, 0)
  stage_df$pct_unweighted <- stage_df$pct_weighted

  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = list(n_unweighted = 438, n_weighted = 438)))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  overview <- .sfs_overview_step(block, "FOC")

  expect_identical(overview$from, "aware")
  expect_identical(overview$to, "consideration")
  expect_equal(overview$ratio, 0)

  # The engine agrees: a zero preceding stage gives NA, not an infinite fall.
  conv_df <- calculate_conversions(stage_df, method = "ratio")
  sub <- conv_df[conv_df$brand_code == "FOC", , drop = FALSE]
  expect_true(any(is.na(sub$value)))
})
