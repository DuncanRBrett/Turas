# ==============================================================================
# MAXDIFF TESTS - V2 REPORT ISLAND
# ==============================================================================
#
# The island is the module's contribution to the tabs v2 report. What matters:
# it names its estimator honestly, absent blocks are ABSENT (not {}), item
# order follows the config, and the file round-trips through JSON with a
# hostile label intact.
# ==============================================================================

make_island_fixture <- function(with_hb = "eb", with_logit = TRUE, with_turf = FALSE,
                                with_anchor = FALSE, n_resp = 20) {
  td <- generate_test_data(n_resp = n_resp, n_items = 6, n_tasks = 6, items_per_task = 3)
  items <- td$items
  items$Item_Label[2] <- 'Item B <script>alert(1)</script> & "quotes"'
  ids <- items$Item_ID

  counts <- data.frame(
    Item_ID = ids, Item_Label = items$Item_Label, Item_Group = items$Item_Group,
    Times_Shown = 60, Times_Best = c(30, 20, 15, 10, 5, 3),
    Times_Worst = c(2, 4, 8, 12, 20, 30),
    Best_Pct = c(50, 33.3, 25, 16.7, 8.3, 5), Worst_Pct = c(3.3, 6.7, 13.3, 20, 33.3, 50),
    Net_Score = c(46.7, 26.7, 11.7, -3.3, -25, -45), BW_Score = c(.47, .27, .12, -.03, -.25, -.45),
    Rank = 1:6, stringsAsFactors = FALSE
  )
  logit <- if (with_logit) list(
    utilities = data.frame(Item_ID = ids, Logit_Utility = c(1.5, 1.0, .5, .2, -.4, 0),
                           Logit_SE = c(.1, .1, .1, .1, .1, NA), stringsAsFactors = FALSE),
    model_fit = list(log_likelihood = -120, aic = 250)
  ) else NULL
  hb <- NULL
  if (!identical(with_hb, "none")) {
    indiv <- cbind(resp_id = sprintf("R%03d", seq_len(n_resp)),
                   as.data.frame(td$individual_utils), stringsAsFactors = FALSE)
    hb <- list(
      population_utilities = data.frame(
        Item_ID = ids, HB_Utility_Mean = colMeans(td$individual_utils),
        HB_Utility_SD = apply(td$individual_utils, 2, sd), stringsAsFactors = FALSE),
      individual_utilities = indiv,
      diagnostics = list(method = if (with_hb == "stan") "cmdstanr" else "empirical_bayes"),
      model_fit = list(method = if (with_hb == "stan") "cmdstanr" else "empirical_bayes_shrinkage")
    )
  }
  turf <- if (with_turf) list(
    status = "PASS",
    incremental_table = data.frame(Step = 1:3, Item_ID = ids[1:3], Item_Label = items$Item_Label[1:3],
                                   Reach_Pct = c(40, 62, 75), Incremental_Pct = c(40, 22, 13),
                                   Frequency = c(1, 1.3, 1.6), stringsAsFactors = FALSE),
    threshold_method = "ABOVE_MEAN", n_respondents = n_resp, max_items_evaluated = 3
  ) else NULL
  anchor <- if (with_anchor) data.frame(
    Item_ID = ids, Item_Label = items$Item_Label, Anchor_Count = c(15, 12, 6, 4, 2, 1),
    Anchor_Rate = c(.75, .6, .3, .2, .1, .05), Is_Must_Have = c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  ) else NULL

  os <- get_default_output_settings()
  os$Generate_Simulator <- TRUE
  # The standalone simulator file exists only when the classic HTML report is
  # off (review F3); the default has it on.
  os$Generate_HTML_Report <- FALSE
  os$Anchor_Variable <- "MustHave"
  config <- list(
    project_settings = list(Project_Name = "IslandTest", Weight_Variable = NULL),
    items = items,
    output_settings = os
  )
  out_dir <- file.path(tempdir(), paste0("md_island_", as.integer(runif(1) * 1e6)))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  results <- list(
    count_scores = counts, logit_results = logit, hb_results = hb,
    turf_results = turf, anchor_data = anchor, discrimination_data = NULL,
    # A wide design file, the shape load_design_file() returns.
    design = data.frame(Version = 1L, Task_Number = 1:6,
                        Item1_ID = ids[c(1, 2, 3, 4, 5, 6)], Item2_ID = ids[c(2, 3, 4, 5, 6, 1)],
                        Item3_ID = ids[c(3, 4, 5, 6, 1, 2)], stringsAsFactors = FALSE),
    study_summary = list(n_respondents = n_resp, n_tasks = 6, n_items = 6, weighted = FALSE),
    output_path = file.path(out_dir, "IslandTest_MaxDiff_Results.xlsx")
  )
  list(results = results, config = config, items = items, out_dir = out_dir)
}

test_that("the island names its estimator honestly for each path", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$kind, "maxdiff")
  expect_equal(isl$meta$method, "empirical_bayes")
  expect_match(isl$meta$estimationNote, "not Bayesian posterior", fixed = TRUE)

  fx <- make_island_fixture(with_hb = "stan")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$method, "stan_hb")
  expect_match(isl$meta$methodLabel, "Stan", fixed = TRUE)

  fx <- make_island_fixture(with_hb = "none", with_logit = TRUE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$method, "aggregate_logit")
  expect_null(isl$scores$hbUtility)

  fx <- make_island_fixture(with_hb = "none", with_logit = FALSE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$method, "counts")
  expect_null(isl$scores$share)
  expect_null(isl$scores$logitUtility)
  expect_equal(isl$scores$netScore, fx$results$count_scores$Net_Score)
})

test_that("scores travel in config item order with shares that sum to 100", {
  fx <- make_island_fixture(with_hb = "eb")
  # Reverse the display order: the island must follow it, not the frame order.
  fx$config$items$Display_Order <- 6:1
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$scores$itemId, rev(fx$items$Item_ID))
  expect_equal(isl$scores$label, rev(fx$items$Item_Label))
  expect_equal(isl$scores$bestPct, rev(fx$results$count_scores$Best_Pct))
  expect_equal(length(isl$scores$share), 6)
  expect_equal(sum(isl$scores$share), 100, tolerance = 1e-6)
  expect_equal(length(isl$scores$rescaled), 6)
  expect_equal(isl$scores$rescaleMethod, "0_100")
  expect_equal(isl$meta$nItems, 6)
  expect_equal(isl$meta$itemsPerTask, 3)
  expect_true(isl$meta$frozen)
  expect_equal(isl$meta$simulatorFile, "IslandTest_MaxDiff_Results_simulator.html")
})

test_that("the mean's standard error travels only when a posterior produced one", {
  # F5: HB_Utility_SD is the spread across respondents on BOTH paths, so the
  # only thing that tells them apart in the island is HB_Mean_SE.
  f <- make_island_fixture(with_hb = "stan")
  f$results$hb_results$population_utilities$HB_Mean_SE <-
    c(.04, .05, .06, .07, .08, .09)
  isl <- serialize_maxdiff_layer(f$results, f$config, verbose = FALSE)
  expect_equal(isl$scores$hbMeanSe, c(.04, .05, .06, .07, .08, .09))
  expect_true(!is.null(isl$scores$hbSpread))

  # Under the fallback the column exists in the frame but is empty, and an
  # array of nulls is worse than no array at all.
  g <- make_island_fixture(with_hb = "eb")
  g$results$hb_results$population_utilities$HB_Mean_SE <- NA_real_
  isl2 <- serialize_maxdiff_layer(g$results, g$config, verbose = FALSE)
  expect_null(isl2$scores$hbMeanSe)
  expect_true(!is.null(isl2$scores$hbSpread))
})

test_that("F1: the Stan note never calls the spread a posterior SD", {
  fx <- make_island_fixture(with_hb = "stan")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  # One meaning on both paths: the spread is across respondents; the mean's
  # precision is named as Mean SE and never as "the spread".
  expect_match(isl$meta$estimationNote, "across respondents", fixed = TRUE)
  expect_false(grepl("spread column is the posterior", isl$meta$estimationNote, ignore.case = TRUE))
  expect_match(isl$meta$estimationNote, "Mean SE", fixed = TRUE)
})

test_that("F3: no simulator file is named when the classic HTML report embeds it", {
  fx <- make_island_fixture(with_hb = "eb")
  fx$config$output_settings$Generate_Simulator <- TRUE
  fx$config$output_settings$Generate_HTML_Report <- TRUE
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_null(isl$meta$simulatorFile)
  # YES/NO strings, the shape a config sheet carries before parsing, agree.
  fx$config$output_settings$Generate_HTML_Report <- "NO"
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$simulatorFile, "IslandTest_MaxDiff_Results_simulator.html")
})

test_that("F2: a one-step TURF is written as arrays, not scalars", {
  fx <- make_island_fixture(with_hb = "eb", with_turf = TRUE, with_anchor = TRUE)
  it <- fx$results$turf_results$incremental_table[1, , drop = FALSE]
  fx$results$turf_results$incremental_table <- it
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  txt <- paste(readLines(res$output_file, warn = FALSE), collapse = "")
  expect_true(grepl('"step":[1]', txt, fixed = TRUE), info = txt)
  expect_true(grepl('"reachPct":[40]', txt, fixed = TRUE))
  expect_true(grepl('"itemId":["', txt, fixed = TRUE))
  # The block's own scalars stay scalars, and so does everything in meta.
  expect_true(grepl('"thresholdMethod":"ABOVE_MEAN"', txt, fixed = TRUE))
  expect_true(grepl('"maxItems":3', txt, fixed = TRUE))
  expect_true(grepl('"threshold":0.5', txt, fixed = TRUE))
  expect_true(grepl('"method":"empirical_bayes"', txt, fixed = TRUE))
  expect_true(grepl('"nItems":6', txt, fixed = TRUE))
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_true(is.list(back$turf$step))
  expect_equal(length(back$turf$step), 1)
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("absent blocks are absent in the JSON, never an empty object", {
  fx <- make_island_fixture(with_hb = "none", with_logit = FALSE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("turf" %in% names(isl))
  expect_false("anchor" %in% names(isl))
  expect_false("discrimination" %in% names(isl))
  js <- as.character(jsonlite::toJSON(isl, auto_unbox = TRUE, na = "null"))
  expect_false(grepl('"turf":{}', js, fixed = TRUE))
  expect_false(grepl(':{}', js, fixed = TRUE))
  # No simulator was asked for, so no file is named.
  fx$config$output_settings$Generate_Simulator <- FALSE
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_null(isl$meta$simulatorFile)
})

test_that("TURF and anchor blocks carry their tables", {
  fx <- make_island_fixture(with_hb = "eb", with_turf = TRUE, with_anchor = TRUE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$turf$step, 1:3)
  expect_equal(isl$turf$reachPct, c(40, 62, 75))
  expect_equal(isl$turf$thresholdMethod, "ABOVE_MEAN")
  expect_equal(isl$anchor$isMustHave, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(isl$anchor$variable, "MustHave")
  expect_equal(isl$anchor$threshold, 0.5)
})

test_that("write_maxdiff_island writes a file that reads back as a maxdiff contribution", {
  fx <- make_island_fixture(with_hb = "eb", with_turf = TRUE)
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  expect_equal(res$status, "PASS")
  expect_equal(res$n_items, 6)
  expect_equal(basename(res$output_file), "IslandTest_MaxDiff_Results_md_island.json")
  expect_true(file.exists(res$output_file))

  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_equal(back$meta$kind, "maxdiff")
  expect_equal(back$meta$schema, 1)
  # The hostile label went in and comes out unchanged: escaping is the tabs
  # bundler's job at embed time, not the writer's.
  expect_equal(back$scores$label[[2]], fx$items$Item_Label[2])
  expect_equal(length(back$turf$step), 3)
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("nothing scored refuses instead of writing an empty tab", {
  fx <- make_island_fixture(with_hb = "none", with_logit = FALSE)
  fx$results$count_scores <- NULL
  expect_null(serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE))
  expect_error(write_maxdiff_island(fx$results, fx$config, verbose = FALSE),
               "MODEL_NO_ISLAND_CONTENT")
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("the output stage wires both contributions in and survives a refusal", {
  src <- paste(readLines(file.path(TURAS_ROOT, "modules", "maxdiff", "R", "00_main.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl("export_maxdiff_shares_for_tabs(results, config", src, fixed = TRUE))
  expect_true(grepl("write_maxdiff_island(results, config", src, fixed = TRUE))
  expect_true(grepl('"12_tabs_export.R"', src, fixed = TRUE))
  expect_true(grepl('"13_v2_island.R"', src, fixed = TRUE))
  # A refusal from the exporter is caught as a turas_refusal, not an error
  # that aborts the Excel deliverable already written.
  expect_true(grepl("turas_refusal = function(e)", src, fixed = TRUE))
})


# ==============================================================================
# DIAGNOSTICS BLOCK (section 6 parity)
# ==============================================================================
# The classic report's diagnostics panel shows four groups of stat cards. Two
# of its groups were dead: transform_diagnostics_section() read the logit fit
# from results$logit_results$fit_stats, but the module writes model_fit, and
# build_diagnostics_table() was never called by any panel. The island reads
# the key that exists.

test_that("the diagnostics block carries the classic panel's statistics", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  d <- isl$diagnostics
  expect_false(is.null(d))

  # Population utility statistics, the classic panel's second card group.
  for (f in c("utilityRange", "meanUtility", "utilitySd", "discrimination")) {
    expect_true(f %in% names(d), info = f)
    expect_length(d[[f]], 1L)
    expect_true(is.finite(d[[f]]), info = f)
  }
  # Model quality indicators, its third group.
  for (f in c("meanMaxShare", "chanceLevel", "sharpnessRatio", "entropyRatio",
              "heterogeneity")) {
    expect_true(f %in% names(d), info = f)
    expect_length(d[[f]], 1L)
  }
  # Respondent utility distribution, its fourth group.
  for (f in c("meanRespondentRange", "minRespondentRange", "maxRespondentRange")) {
    expect_true(f %in% names(d), info = f)
    expect_length(d[[f]], 1L)
  }
  # Chance level is one over the number of items, as a percentage.
  expect_equal(d$chanceLevel, round(100 / 6, 1))
  # Discrimination is the utility range divided by the item count.
  expect_equal(d$discrimination, round(d$utilityRange / 6, 3))
  # A range cannot be negative and the minimum cannot exceed the maximum.
  expect_gte(d$utilityRange, 0)
  expect_lte(d$minRespondentRange, d$maxRespondentRange)
})

test_that("model fit is read from model_fit, the key the module actually writes", {
  fx <- make_island_fixture(with_hb = "eb", with_logit = TRUE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$diagnostics$logLikelihood, -120)
  expect_equal(isl$diagnostics$aic, 250)

  # The classic report read fit_stats. Nothing writes that key, so a fixture
  # carrying only fit_stats must produce no fit numbers at all.
  fx2 <- make_island_fixture(with_hb = "eb", with_logit = TRUE)
  fx2$results$logit_results$model_fit <- NULL
  fx2$results$logit_results$fit_stats <- list(log_likelihood = -99, aic = 1)
  isl2 <- serialize_maxdiff_layer(fx2$results, fx2$config, verbose = FALSE)
  expect_null(isl2$diagnostics$logLikelihood)
  expect_null(isl2$diagnostics$aic)
})

test_that("the diagnostics block counts configured segments", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$diagnostics$nSegments, 0L)

  fx$config$segment_settings <- data.frame(
    Segment_ID = c("S1", "S2"), Segment_Label = c("Age", "Region"),
    stringsAsFactors = FALSE
  )
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$diagnostics$nSegments, 2L)
})

test_that("the diagnostics block is absent, not empty, with no utilities to describe", {
  fx <- make_island_fixture(with_hb = "none", with_logit = FALSE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("diagnostics" %in% names(isl))
  js <- as.character(jsonlite::toJSON(isl, auto_unbox = TRUE, na = "null"))
  expect_false(grepl('"diagnostics"', js, fixed = TRUE))
})

test_that("every diagnostics field serialises as a JSON scalar, not a one-element array", {
  # .maxdiff_island_keep_arrays() is an INVERTED whitelist: it names the
  # scalar fields of each block and wraps everything else in I(). A block
  # missing from that list ships its scalars as [x], and the panel reads them
  # wrong or vanishes.
  fx <- make_island_fixture(with_hb = "eb")
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  d <- back$diagnostics
  expect_false(is.null(d))
  for (f in names(d)) {
    expect_length(d[[f]], 1L)
    expect_false(is.list(d[[f]]), info = paste(f, "serialised as an array"))
  }
  unlink(fx$out_dir, recursive = TRUE)
})


# ==============================================================================
# HEAD-TO-HEAD BLOCK (section 6 parity)
# ==============================================================================
# The classic report draws an n by n win-probability matrix. The island carries
# the upper triangle only: P(j beats i) is exactly 1 - P(i beats j), so the
# mirror is derived in the tab and the payload halves.

test_that("head to head carries the upper triangle in island item order", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  h <- isl$headToHead
  expect_false(is.null(h))

  n <- length(isl$scores$itemId)
  expect_equal(length(h$rowItem), n * (n - 1) / 2)
  expect_equal(length(h$colItem), length(h$rowItem))
  expect_equal(length(h$prob), length(h$rowItem))

  # Every pair appears once, row before column in the island's item order.
  ids <- isl$scores$itemId
  expect_true(all(h$rowItem %in% ids))
  expect_true(all(h$colItem %in% ids))
  expect_equal(anyDuplicated(paste(h$rowItem, h$colItem)), 0L)
  expect_true(all(match(h$rowItem, ids) < match(h$colItem, ids)))

  # A probability is a percentage, and no pair compares an item with itself.
  expect_true(all(h$prob >= 0 & h$prob <= 100))
  expect_false(any(h$rowItem == h$colItem))
})

test_that("head to head agrees with compute_head_to_head, the classic report's own function", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  h <- isl$headToHead
  indiv <- fx$results$hb_results$individual_utilities

  for (k in seq_len(min(5L, length(h$prob)))) {
    ref <- compute_head_to_head(indiv, h$rowItem[k], h$colItem[k])
    expect_equal(h$prob[k], ref$prob_a, tolerance = 1e-8,
                 info = paste(h$rowItem[k], "vs", h$colItem[k]))
  }
})

test_that("head to head falls back to aggregate utilities and says so", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$headToHead$source, "individual")

  # No individual utilities: the population means still support a comparison.
  fx$results$hb_results$individual_utilities <- NULL
  isl2 <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl2$headToHead$source, "aggregate")
  expect_equal(length(isl2$headToHead$prob), length(isl$headToHead$prob))
  expect_match(isl2$headToHead$note, "population", fixed = TRUE)

  # Aggregate logit only.
  fx3 <- make_island_fixture(with_hb = "none", with_logit = TRUE)
  isl3 <- serialize_maxdiff_layer(fx3$results, fx3$config, verbose = FALSE)
  expect_equal(isl3$headToHead$source, "aggregate")
})

test_that("head to head is absent when nothing can be compared", {
  fx <- make_island_fixture(with_hb = "none", with_logit = FALSE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("headToHead" %in% names(isl))
  js <- as.character(jsonlite::toJSON(isl, auto_unbox = TRUE, na = "null"))
  expect_false(grepl('"headToHead"', js, fixed = TRUE))
})

test_that("head to head keeps its per-pair fields as arrays and its scalars scalar", {
  fx <- make_island_fixture(with_hb = "eb")
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  h <- back$headToHead
  expect_true(is.list(h$rowItem))
  expect_true(is.list(h$colItem))
  expect_true(is.list(h$prob))
  expect_equal(length(h$prob), 15)          # 6 items, 6 * 5 / 2
  expect_false(is.list(h$source))
  expect_false(is.list(h$note))
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("head to head survives two items, the smallest matrix there is", {
  fx <- make_island_fixture(with_hb = "eb")
  fx$config$items$Include[3:6] <- 0
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  h <- isl$headToHead
  expect_equal(length(h$prob), 1L)
  expect_equal(h$rowItem, isl$scores$itemId[1])
  expect_equal(h$colItem, isl$scores$itemId[2])
})


# ==============================================================================
# SEGMENTS BLOCK (section 6 parity)
# ==============================================================================
# The classic Segments panel never worked: build_segment_table() prints the
# internal list names as headings with Times_Shown and Rank as its columns, and
# build_segment_chart() returns an empty string because it wants wide
# BW_Score_<level> columns that 08_segments.R does not produce. Proved by
# running both against the real shape, 18 Sep 2026. So this block is a build,
# not a port.

make_segment_results <- function(ids, levels = c("18-34", "35+"), base = 120L,
                                 variable = "Age", segment_id = "S1") {
  scores <- do.call(rbind, lapply(seq_along(levels), function(k) data.frame(
    Item_ID = ids, Item_Label = paste("Item", seq_along(ids)),
    Times_Shown = 30L,
    Best_Pct = seq(50, 10, length.out = length(ids)) + k,
    Worst_Pct = seq(5, 45, length.out = length(ids)) - k,
    Net_Score = seq(45, -35, length.out = length(ids)) + k,
    BW_Score = seq(.45, -.35, length.out = length(ids)),
    Rank = seq_along(ids),
    Segment_ID = segment_id, Segment_Label = variable,
    Segment_Value = levels[k], Segment_N = base,
    stringsAsFactors = FALSE
  )))
  list(
    segment_scores = scores,
    segment_summary = data.frame(
      Segment_ID = segment_id, Segment_Label = variable,
      Segment_Value = levels, N = base, stringsAsFactors = FALSE
    )
  )
}

test_that("segments travel as one row per item per level, in island item order", {
  fx <- make_island_fixture(with_hb = "eb")
  ids <- as.character(fx$items$Item_ID)
  fx$results$segment_results <- make_segment_results(ids)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  s <- isl$segments
  expect_false(is.null(s))

  expect_equal(length(s$itemId), length(ids) * 2L)
  for (f in c("variable", "level", "base", "itemId", "netScore", "bestPct", "worstPct")) {
    expect_equal(length(s[[f]]), length(s$itemId), info = f)
  }
  expect_equal(unique(s$variable), "Age")
  expect_equal(unique(s$level), c("18-34", "35+"))
  # Item order inside each level follows the island, not the segment frame.
  expect_equal(s$itemId[seq_along(ids)], isl$scores$itemId)
})

test_that("segments carry the base and the minimum the config set for it", {
  fx <- make_island_fixture(with_hb = "eb")
  ids <- as.character(fx$items$Item_ID)
  fx$results$segment_results <- make_segment_results(ids, base = 30L)
  fx$config$output_settings$Min_Respondents_Per_Segment <- 50
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_true(all(isl$segments$base == 30))
  expect_equal(isl$segments$minBase, 50)
  expect_length(isl$segments$minBase, 1L)
})

test_that("segments keep every configured variable apart", {
  fx <- make_island_fixture(with_hb = "eb")
  ids <- as.character(fx$items$Item_ID)
  a <- make_segment_results(ids, levels = c("18-34", "35+"), variable = "Age",
                            segment_id = "S1")
  b <- make_segment_results(ids, levels = c("North", "South"), variable = "Region",
                            segment_id = "S2", base = 200L)
  fx$results$segment_results <- list(
    segment_scores = rbind(a$segment_scores, b$segment_scores),
    segment_summary = rbind(a$segment_summary, b$segment_summary)
  )
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  s <- isl$segments
  expect_equal(unique(s$variable), c("Age", "Region"))
  expect_equal(length(s$itemId), length(ids) * 4L)
  expect_true(all(s$base[s$variable == "Region"] == 200))
})

test_that("segments are absent when no segment analysis ran", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("segments" %in% names(isl))
  js <- as.character(jsonlite::toJSON(isl, auto_unbox = TRUE, na = "null"))
  expect_false(grepl('"segments"', js, fixed = TRUE))

  # An empty frame is nothing to show, not a block of empty arrays.
  fx$results$segment_results <- list(
    segment_scores = make_segment_results("I1")$segment_scores[0, ],
    segment_summary = NULL
  )
  isl2 <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("segments" %in% names(isl2))
})

test_that("segments keep per-row fields as arrays and scalars scalar", {
  fx <- make_island_fixture(with_hb = "eb")
  ids <- as.character(fx$items$Item_ID)
  fx$results$segment_results <- make_segment_results(ids)
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  s <- back$segments
  for (f in c("variable", "level", "base", "itemId", "netScore", "bestPct", "worstPct")) {
    expect_true(is.list(s[[f]]), info = paste(f, "must be a JSON array"))
  }
  expect_false(is.list(s$minBase))
  expect_false(is.list(s$note))
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("a single level with a single item still ships as arrays, not scalars", {
  # The F2 lesson: a length-1 per-row field that unboxes makes the panel
  # vanish, and one small segment level is the case that produces it.
  fx <- make_island_fixture(with_hb = "eb")
  fx$config$items$Include[2:6] <- 0
  ids <- as.character(fx$items$Item_ID[1])
  fx$results$segment_results <- make_segment_results(ids, levels = "18-34")
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_true(is.list(back$segments$itemId))
  expect_equal(length(back$segments$itemId), 1L)
  expect_true(is.list(back$segments$netScore))
  unlink(fx$out_dir, recursive = TRUE)
})


# ==============================================================================
# DISTRIBUTIONS BLOCK (section 6 parity)
# ==============================================================================
# Feeds the raincloud/violin chart. The densities travel FLAT, two vectors of
# nItems * nPoints with a stride, so every field in the block is a plain array
# like every other block and no nested structure has to survive jsonlite.

test_that("distributions carry per-item summary statistics in island item order", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  d <- isl$distributions
  expect_false(is.null(d))

  n <- length(isl$scores$itemId)
  expect_equal(d$itemId, isl$scores$itemId)
  for (f in c("mean", "median", "sd", "q25", "q75", "min", "max")) {
    expect_equal(length(d[[f]]), n, info = f)
  }
  # A quartile range sits inside the observed range, and the median inside it.
  ok <- is.finite(d$q25) & is.finite(d$q75)
  expect_true(all(d$q25[ok] <= d$q75[ok]))
  expect_true(all(d$min[ok] <= d$q25[ok]))
  expect_true(all(d$q75[ok] <= d$max[ok]))
})

test_that("densities travel flat with a stride the tab can slice", {
  fx <- make_island_fixture(with_hb = "eb")
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  d <- isl$distributions
  n <- length(isl$scores$itemId)

  expect_length(d$nPoints, 1L)
  expect_equal(length(d$densityX), n * d$nPoints)
  expect_equal(length(d$densityY), n * d$nPoints)

  # Slice item 1 the way the tab will, and check it looks like a density.
  k <- d$nPoints
  x1 <- d$densityX[seq_len(k)]
  y1 <- d$densityY[seq_len(k)]
  expect_false(anyNA(x1))
  expect_true(all(diff(x1) > 0))        # the grid ascends
  expect_true(all(y1 >= 0))             # a density is never negative
})

test_that("the Stan reference item's flat distribution is blanked, not reported", {
  # The model fixes the reference item at zero for every respondent, so its
  # spread is structural. F6 blanks it in scores and discrimination; it is
  # blanked here for the same reason rather than drawn as a spike.
  fx <- make_island_fixture(with_hb = "stan")
  ids <- as.character(fx$items$Item_ID)
  ref <- ids[length(ids)]
  fx$results$hb_results$model_fit$reference_item <- ref
  fx$results$hb_results$individual_utilities[[ref]] <- 0
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  d <- isl$distributions

  pos <- match(ref, d$itemId)
  expect_false(is.na(pos))
  expect_true(is.na(d$sd[pos]))
  expect_true(is.na(d$q25[pos]))
  k <- d$nPoints
  expect_true(all(is.na(d$densityX[((pos - 1) * k + 1):(pos * k)])))

  # Every other item is untouched.
  others <- setdiff(seq_along(d$itemId), pos)
  expect_false(any(is.na(d$sd[others])))
})

test_that("distributions are absent without individual utilities", {
  fx <- make_island_fixture(with_hb = "none", with_logit = TRUE)
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_false("distributions" %in% names(isl))
  js <- as.character(jsonlite::toJSON(isl, auto_unbox = TRUE, na = "null"))
  expect_false(grepl('"distributions"', js, fixed = TRUE))
})

test_that("distributions keep per-item fields as arrays and the stride scalar", {
  fx <- make_island_fixture(with_hb = "eb")
  res <- write_maxdiff_island(fx$results, fx$config, verbose = FALSE)
  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  d <- back$distributions
  for (f in c("itemId", "mean", "median", "sd", "q25", "q75", "min", "max",
              "densityX", "densityY")) {
    expect_true(is.list(d[[f]]), info = paste(f, "must be a JSON array"))
  }
  expect_false(is.list(d$nPoints))
  expect_false(is.list(d$note))
  unlink(fx$out_dir, recursive = TRUE)
})
