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
