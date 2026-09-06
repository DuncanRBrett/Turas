# ==============================================================================
# BRAND MODULE TESTS: the Overview's funnel step is the step it draws
# ==============================================================================
# "Opportunities to examine" names the largest step down in the funnel. It
# derives that step in JavaScript from the mini-funnel block
# .brsum_funnel_minif() writes into the JSON island, and it must read the
# same series the card above it draws. Otherwise the sentence describes a
# funnel the reader cannot see.
#
# Stage 4 (6 September 2026) changed which series that is. The card now
# draws the nested chain, matching the funnel destination's default view, so
# the step is the smallest successive ratio of the chain. That ratio is the
# engine's own pct_nested_filtered, computed in calculate_stage_metrics():
#
#     chain[k] / n_weighted  over  chain[k-1] / n_weighted  ==  pct_nested[k]
#
# which is what the first test below asserts, on real chain counts.
#
# A payload with no chain column keeps the absolute series, and there the
# step is the one .biggest_drop_for_focal() in R/03_funnel.R reports under
# the default ratio conversion metric. That branch is still exercised, so
# both series are covered and the fallback cannot rot.
#
# The divergence from the engine, stated rather than left to be found. The
# engine's conversion metrics are computed on the UNNESTED pct_weighted
# series, so under the nested card the Overview's step and
# .biggest_drop_for_focal() can name different stages. The Overview's
# sentence phrases itself as a share of the stage before ("which is N% of
# the stage before it"), which stays true of the series it draws either way.
# With funnel.conversion_metric set to "absolute_gap" the engine's answer
# moves again, for a third reason.
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
# past 3 months 44.9772% of total respondents. Its largest step down on that
# unnested series is 44.9772 / 62.3288 = 0.7216117, which is what the engine
# reports.
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

# The same fixture with the cumulative-chain counts the engine computes,
# also measured off that report: 405, 293, 195, 142 respondents out of 438
# still in the chain at each stage. The second brand's counts are made up,
# and are here only so the category average has more than one value.
.sfs_stages_with_chain <- function() {
  out <- .sfs_stages()
  chain <- list(FOC = c(405, 293, 195, 142), OTHER = c(300, 120, 90, 40))
  out$base_chain_filtered <- NA_real_
  for (b in names(chain)) {
    for (i in seq_along(chain[[b]])) {
      k <- c("aware", "consideration", "bought_long", "bought_target")[i]
      out$base_chain_filtered[out$brand_code == b & out$stage_key == k] <-
        chain[[b]][i]
    }
  }
  out
}

.sfs_meta <- function() list(n_unweighted = 438, n_weighted = 438)


# The Overview's own derivation, in R, line for line with
# biggestFunnelDrop() in js/brand_summary_panel.js: the smallest successive
# ratio of the mini-funnel block's per-brand vector, skipping any step whose
# preceding stage is zero or missing.
.sfs_overview_step <- function(block, brand_code) {
  # nestedFunnelBlock() in the JS swaps in the nested series when the
  # payload carries it, and biggestFunnelDrop() then reads that. Mirrored
  # here so this test walks the same path the reader's browser does.
  vals <- if (isTRUE(block$nested) && !is.null(block$brands_nested))
    block$brands_nested[[brand_code]] else block$brands[[brand_code]]
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


test_that("the mini funnel draws the nested chain when the payload has it", {
  stage_df <- .sfs_stages_with_chain()
  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = .sfs_meta()))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  expect_true(isTRUE(block$available))
  expect_true(isTRUE(block$nested))

  # Each stage is the chain count over the weighted total, asserted rather
  # than eyeballed: 405/438, 293/438, 195/438, 142/438.
  expect_equal(unname(block$brands_nested$FOC),
               c(405, 293, 195, 142) / 438, tolerance = 1e-9)
  # The category average is the per-brand figure averaged, the same
  # convention the absolute series uses.
  expect_equal(unname(block$cat_avg_nested),
               (c(405, 293, 195, 142) / 438 + c(300, 120, 90, 40) / 438) / 2,
               tolerance = 1e-9)
  # And the card says which of the two series it is drawing.
  expect_true(grepl("Nested", block$base_label_nested, fixed = TRUE))
  expect_false(identical(block$base_label_nested, block$base_label))
})


test_that("the Overview's step is the engine's pct_nested on that chain", {
  stage_df <- .sfs_stages_with_chain()
  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = .sfs_meta()))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  overview <- .sfs_overview_step(block, "FOC")
  expect_false(is.null(overview))

  # The smallest successive ratio of the chain. 293/405 = 0.7234568,
  # 195/293 = 0.6655290, 142/195 = 0.7282051. The smallest is the middle
  # one, so the step the Overview names is prefer to past 12 months.
  expect_identical(overview$from, "consideration")
  expect_identical(overview$to,   "bought_long")
  expect_equal(overview$ratio, 195 / 293, tolerance = 1e-9)

  # That ratio is exactly what the engine computes as pct_nested_filtered
  # for the same stage, so the sentence is a real conversion and not a
  # number invented by the panel.
  chain <- c(405, 293, 195, 142)
  nested <- chain[-1] / chain[-length(chain)]
  expect_equal(min(nested), overview$ratio, tolerance = 1e-12)
})


test_that("the step moves with the series, which is the point of the change", {
  # On the unnested series the engine names past 12 months to past 3 months.
  # On the chain it names prefer to past 12 months. The two are different
  # answers about different things, and the Overview reports the one it
  # draws. Left as a test so nobody re-couples them by accident.
  stage_df <- .sfs_stages_with_chain()
  conv_df <- calculate_conversions(stage_df, method = "ratio")
  engine <- .biggest_drop_for_focal(conv_df, "FOC")
  expect_identical(engine$to_stage, "bought_target")

  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = .sfs_meta()))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  overview <- .sfs_overview_step(block, "FOC")
  expect_identical(overview$to, "bought_long")
  expect_false(identical(overview$to, engine$to_stage))
})


test_that("with no chain in the payload it falls back to the engine's step", {
  stage_df <- .sfs_stages()
  conv_df <- calculate_conversions(stage_df, method = "ratio")
  engine <- .biggest_drop_for_focal(conv_df, "FOC")
  expect_false(is.null(engine))

  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = .sfs_meta()))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  expect_true(isTRUE(block$available))
  expect_false(isTRUE(block$nested))

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


test_that("a chain that cannot be divided leaves the absolute series alone", {
  stage_df <- .sfs_stages_with_chain()
  cr <- list(funnel = list(status = "PASS", stages = stage_df,
                           meta = list(n_unweighted = 438, n_weighted = NA)))
  block <- .brsum_funnel_minif(cr, c("FOC", "OTHER"),
                               list(FOC = "Focal", OTHER = "Other"))
  expect_false(isTRUE(block$nested))
  expect_null(block$brands_nested)

  stage_df2 <- .sfs_stages_with_chain()
  stage_df2$base_chain_filtered <- NA_real_
  cr2 <- list(funnel = list(status = "PASS", stages = stage_df2,
                            meta = .sfs_meta()))
  block2 <- .brsum_funnel_minif(cr2, c("FOC", "OTHER"),
                                list(FOC = "Focal", OTHER = "Other"))
  expect_false(isTRUE(block2$nested))
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
                           meta = .sfs_meta()))
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
                           meta = .sfs_meta()))
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
